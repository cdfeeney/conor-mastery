@preconcurrency import DeviceActivity
import FamilyControls
import Foundation
import MasteryCore
import Observation

/// Screen Time enforcement (PRD section 5). The app writes a `GateSnapshot` to the App Group and
/// resolves shields with it; the monitor extension re-resolves the same snapshot at every scheduled
/// boundary while the app is closed.
@MainActor @Observable
final class ScreenTimeService {
    /// False in builds signed without the Family Controls entitlement (TestFlight until Apple grants distribution):
    /// Info.plist `MasteryScreenTime` is NO there, and the app says so instead of offering a prompt that fails.
    static let isAvailable = (Bundle.main.object(forInfoDictionaryKey: "MasteryScreenTime") as? String) != "NO"
    static let unavailableMessage = "App blocking turns on once Apple approves Screen Time for this app. Everything else works."

    private(set) var isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
    var selection = SharedGate.loadSelection()
    var lastError: String?

    /// DeviceActivity refuses intervals shorter than 15 minutes.
    private static let minimumInterval = 15

    var hasSelection: Bool {
        !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty || !selection.webDomainTokens.isEmpty
    }

    var canEnforce: Bool { Self.isAvailable && isAuthorized && hasSelection }

    func requestAuthorization() async {
        guard Self.isAvailable else { return }
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
        } catch {
            lastError = "Screen Time permission failed: \(error.localizedDescription)"
        }
    }

    func saveSelection() { SharedGate.save(selection: selection) }

    /// Write the snapshot, resolve shields now, and (re)register the daily schedules.
    /// Call on launch, on foreground and after any habit or settings change.
    func apply(store: MasteryStore) {
        guard Self.isAvailable, isAuthorized else { return }
        let settings = store.settings
        SharedGate.save(snapshot: GateSnapshot(
            config: settings.gate,
            active: settings.gate.enabled && hasSelection,
            morningDoneDay: store.morningGateMet ? store.today : nil,
            unblockUntil: settings.unblockUntil,
            lockedInUntil: settings.lockedInUntil))
        SharedGate.applyResolved()
        if settings.gate.enabled && hasSelection { schedule(settings.gate) } else { stopDailySchedules() }
    }

    /// Paid unblock: schedule the end first, then charge. If either step fails, nothing changes.
    func startUnblock(store: MasteryStore) {
        guard canEnforce else {
            lastError = "Set up Screen Time and choose apps first."
            return
        }
        do {
            try startOneOff(.unblock, minutes: RewardRules.unblockMinutes)
        } catch {
            lastError = "Couldn't start the unlock timer: \(error.localizedDescription)"
            return
        }
        guard store.buyUnblock() else {
            DeviceActivityCenter().stopMonitoring([.unblock])
            return
        }
        apply(store: store)
    }

    func startLockedIn(minutes: Int, store: MasteryStore) {
        guard canEnforce else { return }
        let until = Date.now.addingTimeInterval(TimeInterval(minutes * 60))
        store.setLockedIn(until: until)
        // Shorter sessions still get a 15-minute monitor; the resolver uses lockedInUntil, not the interval.
        try? startOneOff(.lockedIn, minutes: max(minutes, Self.minimumInterval))
        apply(store: store)
    }

    func endLockedIn(store: MasteryStore) {
        DeviceActivityCenter().stopMonitoring([.lockedIn])
        store.setLockedIn(until: nil)
        apply(store: store)
    }

    // MARK: - Private

    private func schedule(_ gate: GateConfig) {
        let center = DeviceActivityCenter()
        do {
            // The wind-down interval only needs a start event; its end wraps past midnight if needed.
            let windDownEnd = ClockTime(minutes: gate.windDown.minutes + 60)
            try center.startMonitoring(.windDown, during: DeviceActivitySchedule(
                intervalStart: components(gate.windDown), intervalEnd: components(windDownEnd), repeats: true))
            let windows = gate.noSocialSchedule ? Array(gate.allowedWindows.prefix(DeviceActivityName.maxSocialWindows)) : []
            for (index, window) in windows.enumerated() {
                let end = paddedEnd(window)
                try center.startMonitoring(.socialWindow(index), during: DeviceActivitySchedule(
                    intervalStart: components(window.start), intervalEnd: components(end), repeats: true))
            }
            let stale = (windows.count..<DeviceActivityName.maxSocialWindows).map { DeviceActivityName.socialWindow($0) }
            center.stopMonitoring(stale)
        } catch {
            lastError = "Couldn't schedule the gate: \(error.localizedDescription)"
        }
    }

    /// Windows shorter than 15 minutes are stretched for the monitor; the resolver still uses the real window.
    private func paddedEnd(_ window: TimeWindow) -> ClockTime {
        let length = (window.end.minutes - window.start.minutes + 1440) % 1440
        return length >= Self.minimumInterval ? window.end : ClockTime(minutes: window.start.minutes + Self.minimumInterval)
    }

    private func stopDailySchedules() {
        let windows = (0..<DeviceActivityName.maxSocialWindows).map { DeviceActivityName.socialWindow($0) }
        DeviceActivityCenter().stopMonitoring([.windDown] + windows)
    }

    private func startOneOff(_ name: DeviceActivityName, minutes: Int) throws {
        let now = Date.now
        let end = now.addingTimeInterval(TimeInterval(max(minutes, Self.minimumInterval) * 60))
        let fields: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        try DeviceActivityCenter().startMonitoring(name, during: DeviceActivitySchedule(
            intervalStart: Calendar.current.dateComponents(fields, from: now),
            intervalEnd: Calendar.current.dateComponents(fields, from: end), repeats: false))
    }

    private func components(_ time: ClockTime) -> DateComponents {
        DateComponents(hour: time.hour, minute: time.minute)
    }
}

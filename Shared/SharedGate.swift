@preconcurrency import DeviceActivity
import FamilyControls
import Foundation
@preconcurrency import ManagedSettings
import MasteryCore

/// Compiled into the app AND the DeviceActivity monitor extension; both reach the same App Group.
enum SharedGate {
    static let appGroup = "group.com.conorfee.conormastery"
    static var storeName: ManagedSettingsStore.Name { ManagedSettingsStore.Name("mastery") }

    private static let selectionKey = "gate.selection.v1"
    private static let snapshotKey = "gate.snapshot.v1"

    static var defaults: UserDefaults { UserDefaults(suiteName: appGroup) ?? .standard }

    // MARK: Selection (apps the gate blocks)

    static func loadSelection() -> FamilyActivitySelection {
        guard let data = defaults.data(forKey: selectionKey),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return FamilyActivitySelection()
        }
        return selection
    }

    static func save(selection: FamilyActivitySelection) {
        if let data = try? JSONEncoder().encode(selection) { defaults.set(data, forKey: selectionKey) }
    }

    // MARK: Snapshot (what the extension needs to decide without the app running)

    static func loadSnapshot() -> GateSnapshot? {
        guard let data = defaults.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(GateSnapshot.self, from: data)
    }

    static func save(snapshot: GateSnapshot) {
        if let data = try? JSONEncoder().encode(snapshot) { defaults.set(data, forKey: snapshotKey) }
    }

    /// The one place shields are decided: same `GatePolicy` in the app and the monitor.
    @discardableResult
    static func applyResolved(now: Date = .now) -> ShieldDecision? {
        guard let snapshot = loadSnapshot() else { return nil }
        let decision = snapshot.decide(now: now)
        if decision.shield { shield() } else { unshield() }
        return decision
    }

    // MARK: Shields

    static func shield() {
        let selection = loadSelection()
        let store = ManagedSettingsStore(named: storeName)
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    }

    static func unshield() {
        ManagedSettingsStore(named: storeName).clearAllSettings()
    }
}

extension DeviceActivityName {
    /// Wind-down start (default 21:30) to 23:59: shields go up.
    static var windDown: DeviceActivityName { DeviceActivityName("mastery.windDown") }
    /// Daily allowed social windows (one activity per window): re-resolve at start and end.
    static func socialWindow(_ index: Int) -> DeviceActivityName { DeviceActivityName("mastery.socialWindow.\(index)") }
    static let maxSocialWindows = 3
    /// One-off paid unblock; shields return when it ends.
    static var unblock: DeviceActivityName { DeviceActivityName("mastery.unblock") }
    /// Locked-in focus session; shields drop when it ends.
    static var lockedIn: DeviceActivityName { DeviceActivityName("mastery.lockedIn") }
}

import Foundation

/// A daily time window; may cross midnight (start > end).
public struct TimeWindow: Codable, Sendable, Hashable {
    public let start: ClockTime
    public let end: ClockTime

    public init(start: ClockTime, end: ClockTime) {
        self.start = start
        self.end = end
    }

    public func contains(_ time: ClockTime) -> Bool {
        if start <= end { return time >= start && time < end }
        return time >= start || time < end
    }
}

public struct GateConfig: Codable, Sendable, Hashable {
    public let enabled: Bool
    /// Distraction apps lock from here until the morning routine is done.
    public let windDown: ClockTime
    /// Habit that unlocks the morning gate.
    public let morningHabitID: String
    /// When true, distraction apps stay locked all day except in `allowedWindows`.
    public let noSocialSchedule: Bool
    public let allowedWindows: [TimeWindow]

    public init(enabled: Bool = true, windDown: ClockTime = ClockTime(hour: 21, minute: 30),
                morningHabitID: String = "morning-routine", noSocialSchedule: Bool = true,
                allowedWindows: [TimeWindow] = [TimeWindow(start: ClockTime(hour: 19, minute: 0), end: ClockTime(hour: 19, minute: 30))]) {
        self.enabled = enabled; self.windDown = windDown; self.morningHabitID = morningHabitID
        self.noSocialSchedule = noSocialSchedule; self.allowedWindows = allowedWindows
    }
}

public enum ShieldReason: String, Codable, Sendable {
    case lockedInFocus, windDown, morningGate, noSocialSchedule
}

public struct ShieldDecision: Sendable, Hashable {
    public let shield: Bool
    public let reason: ShieldReason?
    /// When the current state next changes on its own, if known.
    public let message: String

    static func open(_ message: String) -> ShieldDecision { ShieldDecision(shield: false, reason: nil, message: message) }
    static func locked(_ reason: ShieldReason, _ message: String) -> ShieldDecision {
        ShieldDecision(shield: true, reason: reason, message: message)
    }
}

/// Pure policy: should distraction apps be shielded right now? (PRD section 5)
public enum GatePolicy {
    public static func decide(config: GateConfig, now: ClockTime, morningDone: Bool,
                              lockedInActive: Bool, unblockActive: Bool) -> ShieldDecision {
        if lockedInActive { return .locked(.lockedInFocus, "Locked in. Apps open when the session ends.") }
        guard config.enabled else { return .open("Gate off.") }
        if unblockActive { return .open("Paid unblock running.") }
        if now >= config.windDown {
            return .locked(.windDown, "Wind-down. Apps open after your morning routine.")
        }
        if !morningDone {
            return .locked(.morningGate, "Finish your morning routine to unlock.")
        }
        if config.noSocialSchedule && !config.allowedWindows.contains(where: { $0.contains(now) }) {
            let next = config.allowedWindows.first.map { "Next window \($0.start.text)." } ?? ""
            return .locked(.noSocialSchedule, "No social media. \(next)".trimmingCharacters(in: .whitespaces))
        }
        return .open("Apps open.")
    }
}

/// Everything needed to decide shields with the app closed. The app writes it to the App Group;
/// the DeviceActivity monitor reads it and runs the same `GatePolicy` from every callback, so
/// overlapping intervals (locked-in, unblock, windows, wind-down) always resolve in one priority order.
public struct GateSnapshot: Codable, Sendable, Hashable {
    public let config: GateConfig
    /// Requires a non-empty app selection; false means "never shield".
    public let active: Bool
    public let morningDoneDay: DayKey?
    public let unblockUntil: Date?
    public let lockedInUntil: Date?

    public init(config: GateConfig, active: Bool, morningDoneDay: DayKey?, unblockUntil: Date?, lockedInUntil: Date?) {
        self.config = config; self.active = active; self.morningDoneDay = morningDoneDay
        self.unblockUntil = unblockUntil; self.lockedInUntil = lockedInUntil
    }

    public func decide(now: Date, timeZone: TimeZone = .current) -> ShieldDecision {
        guard active else { return .open("Gate off.") }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let parts = cal.dateComponents([.hour, .minute], from: now)
        return GatePolicy.decide(
            config: config,
            now: ClockTime(hour: parts.hour ?? 0, minute: parts.minute ?? 0),
            morningDone: morningDoneDay == DayKey(date: now, timeZone: timeZone),
            lockedInActive: lockedInUntil.map { $0 > now } ?? false,
            unblockActive: unblockUntil.map { $0 > now } ?? false)
    }
}

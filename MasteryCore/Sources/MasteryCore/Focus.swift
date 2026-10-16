import Foundation

public struct FocusSession: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let day: DayKey
    public let plannedMinutes: Int
    public let focusedMinutes: Int
    public let lockedIn: Bool
    public let note: String?
    /// Habit this session counts for (e.g. "reset-focus"), if any.
    public let habitID: String?

    public init(id: String = UUID().uuidString, day: DayKey, plannedMinutes: Int, focusedMinutes: Int,
                lockedIn: Bool, note: String? = nil, habitID: String? = nil) {
        self.id = id; self.day = day; self.plannedMinutes = plannedMinutes
        self.focusedMinutes = Swift.max(focusedMinutes, 0); self.lockedIn = lockedIn
        self.note = note; self.habitID = habitID
    }

    public var stoppedEarly: Bool { focusedMinutes < plannedMinutes }
}

public enum FocusEngine {
    /// Books a finished session. A penalty never pushes the balance below zero.
    public static func record(_ session: FocusSession, ledger: GritLedger) -> (ledger: GritLedger, reward: Reward) {
        let raw = RewardRules.focusReward(minutes: session.focusedMinutes, lockedIn: session.lockedIn,
                                          stoppedEarly: session.stoppedEarly)
        let grit = Swift.max(raw.grit, -ledger.balance)
        let reward = Reward(grit: grit, xp: raw.xp)
        guard reward != .zero else { return (ledger, reward) }
        let reason: GritReason = grit < 0 ? .penalty : .focus
        let next = ledger.appending(GritTransaction(day: session.day, amount: grit, reason: reason,
                                                    ref: "focus@\(session.id)", xp: raw.xp))
        return (next, reward)
    }

    /// The level a focus/timer habit earns from `minutes` (nil = not enough yet).
    public static func habitLevel(minutes: Int, habit: HabitDefinition) -> CompletionLevel? {
        if let target = habit.targetMinutes, minutes >= target { return .full }
        if let floor = habit.minMinutes, minutes >= floor { return .minimum }
        return nil
    }

    public static func minutes(on day: DayKey, sessions: [FocusSession]) -> Int {
        sessions.filter { $0.day == day }.reduce(0) { $0 + $1.focusedMinutes }
    }
}

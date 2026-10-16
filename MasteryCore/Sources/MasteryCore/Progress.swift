import Foundation

/// Everything the game loop needs, as one immutable value. The app persists the pieces; this computes.
public struct MasteryState: Sendable {
    public let habits: [HabitDefinition]
    public let completions: [Completion]
    public let ledger: GritLedger
    public let startDay: DayKey
    public let strictStreak: Bool
    public let timeZone: TimeZone

    public init(habits: [HabitDefinition], completions: [Completion], ledger: GritLedger,
                startDay: DayKey, strictStreak: Bool = false, timeZone: TimeZone = .current) {
        self.habits = habits; self.completions = completions; self.ledger = ledger
        self.startDay = startDay; self.strictStreak = strictStreak; self.timeZone = timeZone
    }

    public func streak(through today: DayKey) -> StreakState {
        StreakEngine(strict: strictStreak, timeZone: timeZone)
            .evaluate(from: startDay, through: today, habits: habits, completions: completions)
    }

    public func habit(_ id: String) -> HabitDefinition? { habits.first { $0.id == id } }
}

public struct CompletionResult: Sendable {
    public let state: MasteryState
    /// Net reward change (negative when a completion is downgraded or undone).
    public let delta: Reward
}

public enum MasteryEngine {
    /// Records `level` for a habit on `day`. Re-logging the same day reverses the old reward first,
    /// so toggling never farms grit.
    public static func log(_ level: CompletionLevel, habitID: String, day: DayKey, source: CompletionSource = .manual,
                           minutes: Int? = nil, stepsDone: [String] = [], in state: MasteryState) -> CompletionResult {
        guard let habit = state.habit(habitID) else { return CompletionResult(state: state, delta: .zero) }
        // Streak before today counts toward the bonus; today's own completion does not inflate it.
        let streakDays = state.streak(through: day.adding(days: -1, timeZone: state.timeZone)).current
        let reward = RewardRules.habitReward(difficulty: habit.difficulty, level: level, streakDays: streakDays)
        let previous = paidReward(habitID: habitID, day: day, ledger: state.ledger)
        let delta = Reward(grit: reward.grit - previous.grit, xp: reward.xp - previous.xp)

        let completion = Completion(habitID: habitID, day: day, level: level, source: source,
                                    minutes: minutes, stepsDone: stepsDone)
        let ledger = delta == .zero ? state.ledger : state.ledger.appending(
            GritTransaction(day: day, amount: delta.grit, reason: .habit, ref: habitRef(habitID, day), xp: delta.xp)
        )
        let next = MasteryState(habits: state.habits, completions: state.completions + [completion], ledger: ledger,
                                startDay: state.startDay, strictStreak: state.strictStreak, timeZone: state.timeZone)
        return CompletionResult(state: next, delta: delta)
    }

    /// Clears a habit for the day (undo), refunding whatever it paid.
    public static func clear(habitID: String, day: DayKey, in state: MasteryState) -> CompletionResult {
        let previous = paidReward(habitID: habitID, day: day, ledger: state.ledger)
        let remaining = state.completions.filter { !($0.habitID == habitID && $0.day == day) }
        let ledger = previous == .zero ? state.ledger : state.ledger.appending(
            GritTransaction(day: day, amount: -previous.grit, reason: .refund, ref: habitRef(habitID, day), xp: -previous.xp)
        )
        let next = MasteryState(habits: state.habits, completions: remaining, ledger: ledger,
                                startDay: state.startDay, strictStreak: state.strictStreak, timeZone: state.timeZone)
        return CompletionResult(state: next, delta: Reward(grit: -previous.grit, xp: -previous.xp))
    }

    /// Converts a sleep entry into the sleep habit's completion: on target = full, logged = minimum.
    public static func sleepLevel(_ entry: SleepEntry, target: SleepTarget) -> CompletionLevel {
        target.isOnTarget(entry) ? .full : .minimum
    }

    static func habitRef(_ habitID: String, _ day: DayKey) -> String { "\(habitID)@\(day.rawValue)" }

    static func paidReward(habitID: String, day: DayKey, ledger: GritLedger) -> Reward {
        let ref = habitRef(habitID, day)
        return ledger.transactions
            .filter { $0.ref == ref && ($0.reason == .habit || $0.reason == .refund) }
            .reduce(Reward.zero) { $0 + Reward(grit: $1.amount, xp: $1.xp) }
    }
}

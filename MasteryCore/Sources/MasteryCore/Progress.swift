import Foundation

/// Everything the game loop needs, as one immutable value. The app persists the pieces; this computes.
public struct MasteryState: Sendable {
    public let habits: [HabitDefinition]
    public let completions: [Completion]
    public let ledger: GritLedger
    public let startDay: DayKey
    public let strictStreak: Bool
    public let restDays: Set<DayKey>
    public let timeZone: TimeZone

    public init(habits: [HabitDefinition], completions: [Completion], ledger: GritLedger,
                startDay: DayKey, strictStreak: Bool = false, restDays: Set<DayKey> = [], timeZone: TimeZone = .current) {
        self.habits = habits; self.completions = completions; self.ledger = ledger
        self.startDay = startDay; self.strictStreak = strictStreak; self.restDays = restDays; self.timeZone = timeZone
    }

    public func streak(through today: DayKey) -> StreakState {
        StreakEngine(strict: strictStreak, timeZone: timeZone)
            .evaluate(from: startDay, through: today, habits: habits, completions: completions, restDays: restDays)
    }

    /// Strength values as of the start of `day` (today's ticks don't change today's price).
    public func strength(on day: DayKey) -> [String: Double] {
        StrengthEngine.values(habits: habits, completions: completions, from: startDay, until: day,
                              restDays: restDays, timeZone: timeZone)
    }

    public func energy(on day: DayKey) -> EnergyState {
        EnergyEngine.evaluate(habits: habits, completions: completions, from: startDay, until: day,
                              restDays: restDays, levelUpDays: EnergyEngine.levelUpDays(ledger), timeZone: timeZone)
    }

    /// Same state with different completions and/or ledger (keeps the other fields).
    public func with(completions: [Completion]? = nil, ledger: GritLedger? = nil) -> MasteryState {
        MasteryState(habits: habits, completions: completions ?? self.completions, ledger: ledger ?? self.ledger,
                     startDay: startDay, strictStreak: strictStreak, restDays: restDays, timeZone: timeZone)
    }

    public func habit(_ id: String) -> HabitDefinition? { habits.first { $0.id == id } }
}

public struct CompletionResult: Sendable {
    public let state: MasteryState
    /// Net reward change (negative when a completion is downgraded or undone).
    public let delta: Reward
    public var strike: Bool = false
    /// A seed or koi egg earned by this completion (granted once per habit per day).
    public var drop: Drop? = nil
}

public enum MasteryEngine {
    /// Records `level` for a habit on `day`. Re-logging the same day reverses the old reward first,
    /// so toggling never farms grit.
    public static func log(_ level: CompletionLevel, habitID: String, day: DayKey, source: CompletionSource = .manual,
                           minutes: Int? = nil, stepsDone: [String] = [], in state: MasteryState) -> CompletionResult {
        guard let habit = state.habit(habitID) else { return CompletionResult(state: state, delta: .zero) }
        // Strength and habit streak as of the start of the day: today's own tick never inflates its price.
        let strength = state.strength(on: day)[habitID] ?? 0
        let habitStreak = StrengthEngine.habitStreak(habit, completions: state.completions, before: day,
                                                     start: state.startDay, restDays: state.restDays, timeZone: state.timeZone)
        let strike = level.countsAsDone && StrikeRules.isStrike(habitID: habitID, day: day)
        let reward = RewardRules.habitReward(difficulty: habit.difficulty, level: level, strengthValue: strength,
                                             habitStreakDays: habitStreak, strike: strike)
        let previous = paidReward(habitID: habitID, day: day, ledger: state.ledger)
        let delta = Reward(grit: reward.grit - previous.grit, xp: reward.xp - previous.xp)

        let completion = Completion(habitID: habitID, day: day, level: level, source: source,
                                    minutes: minutes, stepsDone: stepsDone)
        var ledger = delta == .zero ? state.ledger : state.ledger.appending(
            GritTransaction(day: day, amount: delta.grit, reason: .habit, ref: habitRef(habitID, day), xp: delta.xp)
        )
        // Drops are granted at most once per habit per day (marked by a zero-grit ledger entry).
        let dropRef = "drop@\(habitID)@\(day.rawValue)"
        var drop: Drop?
        if level.countsAsDone, !ledger.transactions.contains(where: { $0.ref == dropRef }),
           let rolled = DropRules.roll(habitID: habitID, day: day, strengthValue: strength, level: ledger.level.level) {
            drop = rolled
            ledger = ledger.appending(GritTransaction(day: day, amount: 0, reason: .drop, ref: dropRef))
        }
        var result = CompletionResult(state: state.with(completions: state.completions + [completion], ledger: ledger),
                                      delta: delta)
        result.strike = strike && delta.grit > 0
        result.drop = drop
        return result
    }

    /// Clears a habit for the day (undo), refunding whatever it paid.
    public static func clear(habitID: String, day: DayKey, in state: MasteryState) -> CompletionResult {
        let previous = paidReward(habitID: habitID, day: day, ledger: state.ledger)
        let remaining = state.completions.filter { !($0.habitID == habitID && $0.day == day) }
        let ledger = previous == .zero ? state.ledger : state.ledger.appending(
            GritTransaction(day: day, amount: -previous.grit, reason: .refund, ref: habitRef(habitID, day), xp: -previous.xp)
        )
        return CompletionResult(state: state.with(completions: remaining, ledger: ledger),
                                delta: Reward(grit: -previous.grit, xp: -previous.xp))
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

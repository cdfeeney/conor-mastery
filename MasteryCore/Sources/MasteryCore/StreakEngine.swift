import Foundation

public enum DayOutcome: String, Codable, Sendable {
    /// Every required habit done (minimum counts).
    case perfect
    /// Required habits missed, saved by a Second Wind token.
    case saved
    /// Required habits missed, streak broken.
    case missed
    /// Nothing required that day.
    case rest
    /// Today, not finished yet.
    case pending
}

public struct StreakState: Sendable, Hashable {
    public let current: Int
    public let best: Int
    public let secondWinds: Int
    public let perfectDays: Int
    public let outcomes: [DayKey: DayOutcome]
}

/// Perfect Day streak with earned Second Wind tokens (PRD section 4).
public struct StreakEngine: Sendable {
    public static let daysPerToken = 7
    public static let maxTokens = 2

    public let strict: Bool
    public let timeZone: TimeZone

    public init(strict: Bool = false, timeZone: TimeZone = .current) {
        self.strict = strict
        self.timeZone = timeZone
    }

    public func isPerfect(_ day: DayKey, habits: [HabitDefinition], index: CompletionIndex) -> Bool? {
        let required = habits.filter { $0.isRequired(on: day, timeZone: timeZone) }
        guard !required.isEmpty else { return nil }
        return required.allSatisfy { index.isDone($0.id, on: day) }
    }

    /// Replays every day from `start` through `today`.
    public func evaluate(from start: DayKey, through today: DayKey,
                         habits: [HabitDefinition], completions: [Completion]) -> StreakState {
        let index = CompletionIndex(completions)
        var current = 0
        var best = 0
        var tokens = 0
        var perfectDays = 0
        var outcomes: [DayKey: DayOutcome] = [:]

        for day in DayKey.range(start, through: today, timeZone: timeZone) {
            let perfect = isPerfect(day, habits: habits, index: index)
            let outcome: DayOutcome
            switch perfect {
            case .none:
                outcome = .rest
            case .some(true):
                outcome = .perfect
                current += 1
                perfectDays += 1
                if perfectDays % StreakEngine.daysPerToken == 0 && !strict {
                    tokens = Swift.min(tokens + 1, StreakEngine.maxTokens)
                }
            case .some(false) where day == today:
                outcome = .pending
            case .some(false):
                if !strict && tokens > 0 {
                    tokens -= 1
                    outcome = .saved
                } else {
                    current = 0
                    outcome = .missed
                }
            }
            best = Swift.max(best, current)
            outcomes[day] = outcome
        }
        return StreakState(current: current, best: best, secondWinds: tokens,
                           perfectDays: perfectDays, outcomes: outcomes)
    }
}

/// Days since the last slip for an avoid habit (no nicotine, no social media).
public enum CleanStreak {
    public static func daysClean(habitID: String, since start: DayKey, through today: DayKey,
                                 completions: [Completion], timeZone: TimeZone = .current) -> Int {
        let lastSlip = completions
            .filter { $0.habitID == habitID && $0.level == .slipped && $0.day <= today }
            .map(\.day)
            .max()
        let from = lastSlip.map { $0.adding(days: 1, timeZone: timeZone) } ?? start
        guard from <= today else { return 0 }
        // Today counts only once it is confirmed clean.
        let index = CompletionIndex(completions)
        let confirmedToday = index.isDone(habitID, on: today)
        let span = from.days(until: today, timeZone: timeZone)
        return span + (confirmedToday ? 1 : 0)
    }
}

import Foundation

public struct DailyChallenge: Codable, Sendable, Hashable {
    public let day: DayKey
    public let habitID: String
    public let text: String
    public let reward: Int
}

public struct HabitConsistency: Sendable, Hashable {
    public let habitID: String
    public let required: Int
    public let done: Int
    public var rate: Double { required == 0 ? 1 : Double(done) / Double(required) }
}

public enum ConsistencyReport {
    /// Completion rate per habit over the `window` days ending yesterday.
    public static func compute(habits: [HabitDefinition], completions: [Completion], today: DayKey,
                               window: Int = 14, timeZone: TimeZone = .current) -> [HabitConsistency] {
        let index = CompletionIndex(completions)
        let days = DayKey.range(today.adding(days: -window, timeZone: timeZone),
                                through: today.adding(days: -1, timeZone: timeZone), timeZone: timeZone)
        return habits.filter { $0.isActive(on: today) }.map { habit in
            let weekly = WeeklyTargets.consistency(habit, index: index, days: days, timeZone: timeZone)
            let required = days.filter { habit.isRequired(on: $0, timeZone: timeZone) }
            let done = required.filter { index.isDone(habit.id, on: $0) }.count
            return HabitConsistency(habitID: habit.id, required: required.count + weekly.required, done: done + weekly.done)
        }
    }

    /// Lowest rate first; ties keep habit order. Habits never required in the window are skipped.
    public static func weakest(_ report: [HabitConsistency]) -> [HabitConsistency] {
        report.enumerated()
            .filter { $0.element.required > 0 }
            .sorted { ($0.element.rate, $0.offset) < ($1.element.rate, $1.offset) }
            .map(\.element)
    }
}

/// Coach-driven challenge: weakest habit, KB text, rotated by day. Never random filler.
public enum ChallengePicker {
    public static func pick(habits: [HabitDefinition], completions: [Completion], today: DayKey,
                            timeZone: TimeZone = .current) -> DailyChallenge? {
        let report = ConsistencyReport.compute(habits: habits, completions: completions, today: today, timeZone: timeZone)
        let ranked = ConsistencyReport.weakest(report).compactMap { row in habits.first { $0.id == row.habitID } }
        // No history yet: fall back to habit order so day one still has a challenge.
        let candidates = ranked.isEmpty ? habits.filter { $0.isActive(on: today) } : ranked
        guard let habit = candidates.first(where: { !$0.challenges.isEmpty }) else { return nil }
        let dayNumber = abs(DayKey("2026-01-01")!.days(until: today, timeZone: timeZone))
        let text = habit.challenges[dayNumber % habit.challenges.count]
        return DailyChallenge(day: today, habitID: habit.id, text: text, reward: RewardRules.dailyChallengeGrit)
    }
}

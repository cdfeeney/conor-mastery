import Foundation

/// Habit strength (Habitica's task-value drift, re-implemented; research/HABITICA-TEARDOWN.md section 1).
/// Doing a habit raises its value, missing it lowers it, and weak habits pay more:
/// multiplier = 0.9747^value, clamped. The value is derived by replaying history; it is never stored.
public enum HabitTier: String, Codable, Sendable {
    /// Neglected: shows as a wilting plant, pays the most.
    case wilted
    case healthy
    /// Strong: shows as a blooming plant, pays the least.
    case blooming
}

public enum StrengthRules {
    public static let minValue = -47.27
    public static let maxValue = 21.27
    public static let base = 0.9747
    public static let minMultiplier = 0.5
    public static let maxMultiplier = 3.0
    public static let wiltedBelow = -8.0
    public static let bloomingAbove = 8.0

    public static func clamp(_ value: Double) -> Double { Swift.min(Swift.max(value, minValue), maxValue) }

    /// Size of one step at `value` (Habitica's delta). Bigger when the habit is weak.
    public static func step(_ value: Double) -> Double { pow(base, clamp(value)) }

    public static func multiplier(_ value: Double) -> Double {
        Swift.min(Swift.max(step(value), minMultiplier), maxMultiplier)
    }

    public static func tier(_ value: Double) -> HabitTier {
        if value < wiltedBelow { return .wilted }
        if value > bloomingAbove { return .blooming }
        return .healthy
    }
}

public enum StrengthEngine {
    /// Value of every habit after replaying `start ..< end` (end exclusive, so today's own tick
    /// never changes today's price). Full = +step, minimum = +step/2, missed or slipped = -step.
    public static func values(habits: [HabitDefinition], completions: [Completion], from start: DayKey,
                              until end: DayKey, restDays: Set<DayKey> = [], timeZone: TimeZone = .current) -> [String: Double] {
        let index = CompletionIndex(completions)
        var values = Dictionary(uniqueKeysWithValues: habits.map { ($0.id, 0.0) })
        guard start < end else { return values }
        for day in DayKey.range(start, through: end.adding(days: -1, timeZone: timeZone), timeZone: timeZone)
        where !restDays.contains(day) {
            for habit in habits {
                let current = values[habit.id] ?? 0
                let step = StrengthRules.step(current)
                let level = index.completion(habit.id, on: day)?.level
                let change: Double
                switch level {
                case .full?: change = step
                case .minimum?: change = step / 2
                case .slipped?: change = -step
                case .notDone?, nil:
                    change = habit.isRequired(on: day, timeZone: timeZone) ? -step : 0
                }
                values[habit.id] = StrengthRules.clamp(current + change)
            }
        }
        return values
    }

    /// Consecutive required days the habit was done, counting back from `before` (exclusive).
    /// Rest days and non-required days are skipped, not breaks.
    public static func habitStreak(_ habit: HabitDefinition, completions: [Completion], before day: DayKey,
                                   start: DayKey, restDays: Set<DayKey> = [], timeZone: TimeZone = .current) -> Int {
        let index = CompletionIndex(completions)
        var streak = 0
        var cursor = day.adding(days: -1, timeZone: timeZone)
        while cursor >= start {
            if !restDays.contains(cursor) && habit.isRequired(on: cursor, timeZone: timeZone) {
                guard index.isDone(habit.id, on: cursor) else { break }
                streak += 1
            }
            cursor = cursor.adding(days: -1, timeZone: timeZone)
        }
        return streak
    }
}

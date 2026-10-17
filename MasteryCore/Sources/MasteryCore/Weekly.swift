import Foundation

extension DayKey {
    /// The Monday that starts this day's week.
    public func weekStart(timeZone: TimeZone = .current) -> DayKey {
        // Calendar weekday: 1 = Sunday ... 7 = Saturday. Days since Monday: Mon 0 ... Sun 6.
        let sinceMonday = (weekday(timeZone: timeZone) + 5) % 7
        return adding(days: -sinceMonday, timeZone: timeZone)
    }
}

extension Schedule {
    /// The rule in force on `day` (an edited schedule keeps the old rule for earlier days).
    public func current(on day: DayKey) -> Schedule {
        if case .changed(let before, let after, let from) = self {
            return day < from ? before.current(on: day) : after.current(on: day)
        }
        return self
    }

    var weeklyTarget: Int? {
        if case .timesPerWeek(let n) = self { return n }
        return nil
    }
}

public struct WeeklyProgress: Hashable, Sendable {
    public let done: Int
    public let target: Int
    /// Days left in the week including today.
    public let daysLeft: Int
    public let isDoneToday: Bool

    public var isMet: Bool { done >= target }
    /// Only just enough days left to still make it (today counts only if it isn't done yet).
    public var isAtRisk: Bool { !isMet && target - done >= daysLeft - (isDoneToday ? 1 : 0) }
}

/// "N times a week" habits are never required on a single day (streaks and Perfect Days ignore them);
/// they're measured per Monday-start week instead.
public enum WeeklyTargets {
    public static func progress(_ habit: HabitDefinition, index: CompletionIndex, on day: DayKey,
                                timeZone: TimeZone = .current) -> WeeklyProgress? {
        guard let target = habit.schedule.current(on: day).weeklyTarget else { return nil }
        let start = day.weekStart(timeZone: timeZone)
        let week = DayKey.range(start, through: start.adding(days: 6, timeZone: timeZone), timeZone: timeZone)
        // Only days the habit was active and on this weekly rule count, so a switch mid-week or a habit
        // added on Sunday gets a fair (capped) target, and earlier daily ticks don't fill it.
        let eligible = week.filter { isWeekly(habit, on: $0) }
        let done = eligible.filter { $0 <= day && index.isDone(habit.id, on: $0) }.count
        let daysLeft = 7 - start.days(until: day, timeZone: timeZone)
        return WeeklyProgress(done: done, target: min(target, eligible.count), daysLeft: daysLeft,
                              isDoneToday: index.isDone(habit.id, on: day))
    }

    static func isWeekly(_ habit: HabitDefinition, on day: DayKey) -> Bool {
        habit.isActive(on: day) && habit.schedule.current(on: day).weeklyTarget != nil
    }

    /// Still worth a nudge today: target not met, not done today, not slipped today.
    public static func isOpen(_ habit: HabitDefinition, index: CompletionIndex, on day: DayKey,
                              timeZone: TimeZone = .current) -> Bool {
        guard habit.isActive(on: day), let progress = progress(habit, index: index, on: day, timeZone: timeZone) else { return false }
        return !progress.isMet && !index.isDone(habit.id, on: day) && index.completion(habit.id, on: day)?.level != .slipped
    }

    /// For coach rates: Monday weeks lying fully inside `days` and fully on a weekly rule, target summed,
    /// completions capped per week. Days on a daily rule are scored by the caller.
    static func consistency(_ habit: HabitDefinition, index: CompletionIndex, days: [DayKey],
                            timeZone: TimeZone) -> (required: Int, done: Int) {
        guard let first = days.first, let last = days.last else { return (0, 0) }
        var required = 0, done = 0
        var start = first.weekStart(timeZone: timeZone)
        if start < first { start = start.adding(days: 7, timeZone: timeZone) }
        while start.adding(days: 6, timeZone: timeZone) <= last {
            let week = DayKey.range(start, through: start.adding(days: 6, timeZone: timeZone), timeZone: timeZone)
            if let target = habit.schedule.current(on: start).weeklyTarget, week.allSatisfy({ isWeekly(habit, on: $0) }) {
                required += target
                done += min(target, week.filter { index.isDone(habit.id, on: $0) }.count)
            }
            start = start.adding(days: 7, timeZone: timeZone)
        }
        return (required, done)
    }
}

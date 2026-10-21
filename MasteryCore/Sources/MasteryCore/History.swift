import Foundation

/// One square of the GitHub-style history grid.
public enum HistoryMark: String, Sendable, Hashable {
    /// Everything required done in full.
    case full
    /// Everything required done, at least one by its Min (still keeps the streak).
    case minimum
    /// Some of a routine's steps (or a day's habits) done, not all.
    case partial
    /// Required and not done.
    case missed
    /// An avoid habit broken.
    case slipped
    /// Missed, but a Second Wind kept the streak (Perfect Day grid only).
    case saved
    /// Today, nothing logged yet.
    case open
    /// Nothing required: rest day, unscheduled day, or the habit didn't exist yet.
    case off
    case beforeStart
    case future
}

public enum HabitHistory {
    /// One mark for a group of habits on a day: one habit, a routine's steps, or every habit (the Perfect Day grid).
    public static func mark(_ habits: [HabitDefinition], on day: DayKey, today: DayKey, start: DayKey,
                            index: CompletionIndex, restDays: Set<DayKey> = [], timeZone: TimeZone = .current) -> HistoryMark {
        if day > today { return .future }
        if day < start { return .beforeStart }
        let levels = { (defs: [HabitDefinition]) in defs.compactMap { index.completion($0.id, on: day)?.level } }
        let required = restDays.contains(day) ? [] : habits.filter { $0.isRequired(on: day, timeZone: timeZone) }
        guard !required.isEmpty else {
            // Weekly-target or unscheduled days still show what you did; a routine counts only with every step.
            let active = habits.filter { $0.isActive(on: day) }
            if levels(active).contains(.slipped) { return .slipped }
            let done = levels(active).filter(\.countsAsDone)
            if done.isEmpty { return .off }
            return combined(done, of: active.count)
        }
        if levels(required).contains(.slipped) { return .slipped }
        let done = levels(required).filter(\.countsAsDone)
        if !done.isEmpty { return combined(done, of: required.count) }
        return day == today ? .open : .missed
    }

    private static func combined(_ done: [CompletionLevel], of total: Int) -> HistoryMark {
        guard done.count == total else { return .partial }
        return done.contains(.minimum) ? .minimum : .full
    }

    /// `count` week columns, Sunday to Saturday, the last one holding `today`; days after today are nil.
    public static func weeks(endingOn today: DayKey, count: Int, timeZone: TimeZone = .current) -> [[DayKey?]] {
        guard count > 0 else { return [] }
        let firstSunday = today.adding(days: -(today.weekday(timeZone: timeZone) - 1) - 7 * (count - 1), timeZone: timeZone)
        return (0..<count).map { week in
            (0..<7).map { offset in
                let day = firstSunday.adding(days: week * 7 + offset, timeZone: timeZone)
                return day > today ? nil : day
            }
        }
    }
}

/// What still has to happen today to keep the Perfect Day streak (a Min counts).
public enum StreakKeeper {
    public static func open(_ habits: [HabitDefinition], index: CompletionIndex, on day: DayKey,
                            timeZone: TimeZone = .current) -> [HabitDefinition] {
        habits.filter { $0.isRequired(on: day, timeZone: timeZone) && !index.isDone($0.id, on: day) }
    }
}

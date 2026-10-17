import Foundation

/// What the on-phone coach says this week, from your own last 14 days.
public struct CoachAdvice: Hashable, Sendable {
    /// The week's focus habit; nil when every habit is at the target rate.
    public let focusHabitID: String?
    public let focusLine: String
    public let notes: [String]
    /// Habit ids in the order lessons should come: focus first, then weakest.
    public let lessonOrder: [String]
}

/// The adaptive coach. Deterministic rules, no model:
/// - Focus = the first habit in foundation order (sleep, phone, routines, body, mind) under 80% over 14 days.
/// - Habits under 50% get a "do the Min" note; avoid-habits that slipped 2+ times this week get called out.
/// - Sleep notes from your log: short average, or bedtimes spread over an hour.
/// - Everything at 80%+: a "raise the bar" note.
/// ponytail: "times a week" habits are never required on a day, so they sit outside these rates; add a weekly
/// evaluator when the editor offers that schedule again.
public enum CoachAdvisor {
    public static let targetRate = 0.8
    public static let strugglingRate = 0.5
    public static let maxNotes = 4
    static let window = 14
    static let minimumDays = 3
    static let foundationOrder = ["sleep", "no-social-media", "morning-routine", "night-routine", "no-nicotine",
                                  "workout", "meditation", "deep-breathing", "reset-focus"]

    public static func advise(habits: [HabitDefinition], completions: [Completion], sleep: [SleepEntry],
                              today: DayKey, timeZone: TimeZone = .current) -> CoachAdvice? {
        let report = ConsistencyReport.compute(habits: habits, completions: completions, today: today,
                                               window: window, timeZone: timeZone)
            .filter { $0.required >= minimumDays }
        guard !report.isEmpty else { return nil }
        let byID = Dictionary(habits.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let ordered = report.sorted { rank($0.habitID, habits) < rank($1.habitID, habits) }
        let focus = ordered.first { $0.rate < targetRate }

        var notes: [String] = []
        for row in ordered where row.rate < strugglingRate {
            guard let habit = byID[row.habitID] else { continue }
            let fallback = "plan a time and place with the clock button on its card"
            let tip = habit.min.map { "on hard days do the Min (\($0)): it still keeps your streak" } ?? fallback
            notes.append("\(habit.title): \(row.done) of \(row.required) days. \(tip.prefix(1).uppercased() + tip.dropFirst()).")
        }
        notes += slipNotes(habits: habits, completions: completions, today: today, timeZone: timeZone)
        notes += sleepNotes(sleep, today: today, timeZone: timeZone)
        if focus == nil {
            notes.append("Every habit is at 80% or better. Pick one and raise the bar in Settings → Edit habits.")
        }

        let focusLine: String
        if let focus, let habit = byID[focus.habitID] {
            focusLine = "This week: \(habit.title). You did it \(focus.done) of \(focus.required) days; aim for \(Int(targetRate * 100))%."
        } else {
            focusLine = "This week: keep everything going."
        }
        let weakestFirst = ordered.sorted { $0.rate < $1.rate }.map(\.habitID)
        let lessonOrder = ([focus?.habitID].compactMap { $0 } + weakestFirst + habits.map(\.id)).uniqued()
        return CoachAdvice(focusHabitID: focus?.habitID, focusLine: focusLine,
                           notes: Array(notes.prefix(maxNotes)), lessonOrder: lessonOrder)
    }

    /// Foundation habits first, in their order; anything else after, in plan order.
    static func rank(_ id: String, _ habits: [HabitDefinition]) -> Int {
        foundationOrder.firstIndex(of: id) ?? foundationOrder.count + (habits.firstIndex { $0.id == id } ?? 0)
    }

    static func slipNotes(habits: [HabitDefinition], completions: [Completion], today: DayKey,
                          timeZone: TimeZone) -> [String] {
        // The last 7 days including today, counting each day's latest record only (a corrected slip doesn't count).
        let index = CompletionIndex(completions)
        let days = DayKey.range(today.adding(days: -6, timeZone: timeZone), through: today, timeZone: timeZone)
        return habits.filter { $0.kind == .avoid }.compactMap { habit in
            let slips = days.filter { index.completion(habit.id, on: $0)?.level == .slipped }.count
            guard slips >= 2 else { return nil }
            return "\(habit.title) slipped \(slips) times this week. Pin a tip from its library as a rule and plan for the trigger."
        }
    }

    static func sleepNotes(_ entries: [SleepEntry], today: DayKey, timeZone: TimeZone) -> [String] {
        let start = today.adding(days: -(window - 1), timeZone: timeZone)   // 14 nights including last night
        let recent = entries.filter { $0.wakeDay >= start && $0.wakeDay <= today }
        guard recent.count >= minimumDays else { return [] }
        var notes: [String] = []
        let hours = recent.map { $0.hoursSlept ?? $0.hoursInBed(timeZone: timeZone) }
        let average = hours.reduce(0, +) / Double(hours.count)
        if average < 7 {
            notes.append("Averaging \(String(format: "%.1f", average)) h of sleep. Move bedtime 15 minutes earlier this week.")
        }
        // Minutes after noon, so 23:00 and 01:00 sit two hours apart, not 22.
        let bedtimes = recent.map { ($0.bedtime.minutes - 720 + 1440) % 1440 }
        if let low = bedtimes.min(), let high = bedtimes.max(), high - low > 60 {
            notes.append("Bedtimes vary by \(high - low) minutes. Keep them inside a 30-minute window.")
        }
        return notes
    }
}

extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

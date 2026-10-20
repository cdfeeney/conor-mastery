import Foundation

/// The when/where for a habit ("At 07:00 in the kitchen, I will..."), the cheapest strong lever in the KB
/// (implementation intentions, res:gollwitzer2006).
public struct HabitPlan: Codable, Sendable, Hashable {
    public let time: ClockTime?
    public let place: String?

    public init(time: ClockTime?, place: String?) {
        self.time = time
        let trimmed = place?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.place = (trimmed?.isEmpty ?? true) ? nil : String(trimmed!.prefix(60))
    }

    /// "At 07:00 in the kitchen" / "At 07:00" / "In the kitchen" / nil.
    public var cue: String? {
        switch (time, place) {
        case let (t?, p?): return "At \(t.text) in \(p)"
        case let (t?, nil): return "At \(t.text)"
        case let (nil, p?): return "In \(p)"
        default: return nil
        }
    }
}

public enum ReminderKind: String, Codable, Sendable {
    case habitCue, windDownWarning, streakAtRisk
}

public struct Reminder: Codable, Sendable, Hashable {
    /// Stable id so rescheduling replaces instead of duplicating.
    public let id: String
    public let kind: ReminderKind
    public let time: ClockTime
    public let title: String
    public let body: String
}

/// Pure planning of today's local notifications. The app hands the result to UNUserNotificationCenter.
public enum ReminderPlanner {
    public static let windDownLeadMinutes = 15
    public static let streakCheckTime = ClockTime(hour: 20, minute: 30)

    public static func plan(day: DayKey, now: ClockTime, habits: [HabitDefinition], plans: [String: HabitPlan],
                            index: CompletionIndex, gate: GateConfig, streakDays: Int,
                            timeZone: TimeZone = .current) -> [Reminder] {
        let due = habits.filter { $0.isRequired(on: day, timeZone: timeZone) }
        let open = due.filter { !index.isDone($0.id, on: day) && index.completion($0.id, on: day)?.level != .slipped }
        // Weekly-target habits get their cue until the week's target is met; they don't threaten the streak.
        let weeklyOpen = habits.filter { WeeklyTargets.isOpen($0, index: index, on: day, timeZone: timeZone) }
        var out: [Reminder] = []

        // 1. A cue for each open habit that has a planned time still ahead today. A routine's plan is set on the
        //    routine: one cue while any step is open, titled with the first open step.
        var cued = Set<String>()
        for habit in open + weeklyOpen {
            let key = habit.routine ?? habit.id
            guard cued.insert(key).inserted, let plan = plans[key], let time = plan.time, time > now else { continue }
            out.append(Reminder(id: "cue.\(key)", kind: .habitCue, time: time,
                                title: habit.title, body: [plan.cue, habit.identity].compactMap { $0 }.joined(separator: ". ")))
        }

        // 2. Wind-down warning before apps lock.
        let warn = ClockTime(minutes: gate.windDown.minutes - windDownLeadMinutes)
        if gate.enabled && warn > now {
            out.append(Reminder(id: "winddown", kind: .windDownWarning, time: warn, title: "Wind-down in \(windDownLeadMinutes) min",
                                body: "Apps lock at \(gate.windDown.text) until your morning routine is done."))
        }

        // 3. Streak at risk: only when something is still open and there is a streak to lose.
        if !open.isEmpty && streakDays > 0 && streakCheckTime > now {
            let names = open.prefix(3).map(\.title).joined(separator: ", ")
            out.append(Reminder(id: "streak", kind: .streakAtRisk, time: streakCheckTime, title: "\(streakDays)-day streak at risk",
                                body: "Still open: \(names)\(open.count > 3 ? " +\(open.count - 3) more" : ""). The Min version counts."))
        }
        return out.sorted { $0.time < $1.time }
    }
}

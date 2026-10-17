import Foundation

/// The schedules the on-phone editor offers. Anything else in a plan file shows as daily in the editor.
public enum ScheduleChoice: Hashable, Sendable {
    case daily
    /// Calendar weekdays, 1 = Sunday ... 7 = Saturday.
    case weekdays(Set<Int>)
    case perWeek(Int)

    public init(raw: String) {
        let parts = raw.split(separator: ":", maxSplits: 1).map(String.init)
        switch (parts.first, parts.count > 1 ? parts[1] : nil) {
        case ("weekdays", let list?):
            let days = Set(list.split(separator: ",").compactMap { Int($0) }.filter { (1...7).contains($0) })
            self = days.isEmpty ? .daily : .weekdays(days)
        case ("per-week", let n?):
            self = Int(n).map { .perWeek(min(max($0, 1), 7)) } ?? .daily
        default:
            self = .daily
        }
    }

    public var raw: String {
        switch self {
        case .daily: return "daily"
        case .weekdays(let days): return "weekdays:" + days.sorted().map(String.init).joined(separator: ",")
        case .perWeek(let n): return "per-week:\(n)"
        }
    }
}

extension PlanHabit {
    /// Your version of this habit. Id, kind, identity, why, sources and challenges stay the coach's.
    /// Blank Min means no bad-day version; blank steps are dropped.
    public func edited(title: String, full: String, min: String?, group: HabitGroup, difficulty: Difficulty,
                       schedule: ScheduleChoice, steps: [String]?, targetMinutes: Int?, minMinutes: Int?) -> PlanHabit {
        let trimmedMin = min?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSteps = steps?.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return PlanHabit(id: id, title: title.trimmingCharacters(in: .whitespacesAndNewlines), kind: kind,
                         difficulty: difficulty, group: group, schedule: schedule.raw, identity: identity, why: why,
                         full: full.trimmingCharacters(in: .whitespacesAndNewlines),
                         min: trimmedMin?.isEmpty == false ? trimmedMin : nil,
                         steps: cleanSteps, targetMinutes: targetMinutes, minMinutes: minMinutes,
                         citations: citations, challenges: challenges)
    }
}

/// One schedule edit: from `from` on, the habit follows `after`; before it, `before`.
public struct ScheduleChange: Codable, Sendable, Hashable {
    public let from: DayKey
    public let before: String
    public let after: String

    public init(from: DayKey, before: String, after: String) {
        self.from = from; self.before = before; self.after = after
    }
}

public enum HabitEditor {
    public static let customPrefix = "my-"

    /// Coach habits with your edits laid over the coach's latest version (so new sources, challenges or a
    /// changed kind still arrive), then your own habits. Ids stay unique: the coach's habit wins a clash.
    public static func effective(plan: [PlanHabit], edits: [String: PlanHabit], custom: [PlanHabit]) -> [PlanHabit] {
        let coach = plan.map { habit -> PlanHabit in
            guard let mine = edits[habit.id] else { return habit }
            return habit.edited(title: mine.title, full: mine.full, min: mine.min, group: mine.group,
                                difficulty: mine.difficulty, schedule: ScheduleChoice(raw: mine.schedule),
                                steps: habit.kind == .checklist ? mine.steps : habit.steps,
                                targetMinutes: mine.targetMinutes ?? habit.targetMinutes,
                                minMinutes: mine.minMinutes ?? habit.minMinutes)
        }
        let taken = Set(coach.map(\.id))
        var seen = taken
        let own = custom.filter { seen.insert($0.id).inserted }
        return coach + own
    }

    /// The schedule for history: each change keeps earlier days on the rule they had.
    public static func schedule(current: String, changes: [ScheduleChange], anchor: DayKey) -> Schedule {
        let sorted = changes.sorted { $0.from < $1.from }
        guard let first = sorted.first, let last = sorted.last else {
            return PlanHabit.parseSchedule(current, anchor: anchor)
        }
        var result = PlanHabit.parseSchedule(first.before, anchor: anchor)
        for change in sorted {
            let after = change == last ? current : change.after
            result = .changed(before: result, after: PlanHabit.parseSchedule(after, anchor: anchor), from: change.from)
        }
        return result
    }

    /// Record a schedule edit made today. Same-day edits replace each other; editing back to the old rule
    /// on the same day removes the change.
    public static func recording(_ changes: [ScheduleChange], current: String, new: String, today: DayKey) -> [ScheduleChange] {
        guard current != new else { return changes }
        var next = changes
        if let last = next.last, last.from == today {
            next.removeLast()
            if last.before != new { next.append(ScheduleChange(from: today, before: last.before, after: new)) }
        } else {
            next.append(ScheduleChange(from: today, before: current, after: new))
        }
        return next
    }

    /// Nil when the fields are usable, else what to fix.
    public static func problem(title: String, full: String) -> String? {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Give the habit a name." }
        if full.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Say what counts as done." }
        return nil
    }

    /// A new habit of your own, with an id that never clashes (`my-<slug>`, then `-2`, `-3`...).
    public static func newCustom(title: String, kind: HabitKind, group: HabitGroup, full: String,
                                 existingIDs: Set<String>) -> PlanHabit {
        let slug = title.lowercased().map { $0.isLetter || $0.isNumber ? String($0) : "-" }.joined()
            .split(separator: "-").joined(separator: "-")
        let base = customPrefix + (slug.isEmpty ? "habit" : slug)
        var id = base, n = 2
        while existingIDs.contains(id) { id = "\(base)-\(n)"; n += 1 }
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return PlanHabit(id: id, title: clean, kind: kind, difficulty: .medium, group: group, schedule: "daily",
                         identity: "I keep my word to myself.", why: "Your own habit.",
                         full: full.trimmingCharacters(in: .whitespacesAndNewlines),
                         steps: kind == .checklist ? [] : nil,
                         targetMinutes: kind == .timer ? 10 : nil, minMinutes: kind == .timer ? 2 : nil)
    }
}

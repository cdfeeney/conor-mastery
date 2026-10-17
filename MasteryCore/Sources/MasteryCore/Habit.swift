import Foundation

public enum HabitKind: String, Codable, Sendable, CaseIterable {
    /// Do something (workout, meditation).
    case build
    /// Abstain all day (no nicotine, no social media). Confirmed at night.
    case avoid
    /// A list of steps (morning / night routine).
    case checklist
    /// Needs a running timer (meditation, breathing).
    case timer
    /// Completed by a focus session.
    case focus
    /// Sleep log entry.
    case sleep
}

public enum Difficulty: String, Codable, Sendable, CaseIterable {
    case easy, medium, hard
}

public enum HabitGroup: String, Codable, Sendable, CaseIterable {
    case morning, day, night
}

public enum Schedule: Codable, Sendable, Hashable {
    case daily
    /// Calendar weekdays, 1 = Sunday ... 7 = Saturday.
    case weekdays(Set<Int>)
    case everyNDays(n: Int, anchor: DayKey)
    /// Flexible: never required on a given day; counted against a weekly target.
    case timesPerWeek(Int)
    /// You changed the schedule on `from`: earlier days keep the old rule, so an edit never rewrites history.
    indirect case changed(before: Schedule, after: Schedule, from: DayKey)

    /// Whether the habit is required on `day` for a Perfect Day.
    public func isRequired(on day: DayKey, timeZone: TimeZone = .current) -> Bool {
        switch self {
        case .daily:
            return true
        case .weekdays(let days):
            return days.contains(day.weekday(timeZone: timeZone))
        case .everyNDays(let n, let anchor):
            guard n > 0 else { return false }
            let offset = anchor.days(until: day, timeZone: timeZone)
            return offset >= 0 && offset % n == 0
        case .timesPerWeek:
            return false
        case .changed(let before, let after, let from):
            return day < from ? before.isRequired(on: day, timeZone: timeZone) : after.isRequired(on: day, timeZone: timeZone)
        }
    }
}

public struct Citation: Codable, Sendable, Hashable {
    public let source: String
    /// Timestamp ("12:34") for video, page ("p. 41") for books.
    public let locator: String

    public init(source: String, locator: String) {
        self.source = source
        self.locator = locator
    }
}

public struct HabitDefinition: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let title: String
    public let kind: HabitKind
    public let difficulty: Difficulty
    public let group: HabitGroup
    public let schedule: Schedule
    public let identity: String
    public let full: String
    public let min: String?
    public let steps: [String]
    /// Target minutes for timer/focus habits.
    public let targetMinutes: Int?
    public let minMinutes: Int?
    public let why: String
    public let citations: [Citation]
    public let challenges: [String]
    public let isArchived: Bool
    /// Required only on days inside [activeFrom, activeUntil). Keeps history honest when habits are
    /// added, archived or dropped from the plan: past days are judged by the habits that existed then.
    public let activeFrom: DayKey?
    public let activeUntil: DayKey?

    public init(
        id: String, title: String, kind: HabitKind, difficulty: Difficulty, group: HabitGroup,
        schedule: Schedule = .daily, identity: String, full: String, min: String? = nil,
        steps: [String] = [], targetMinutes: Int? = nil, minMinutes: Int? = nil,
        why: String = "", citations: [Citation] = [], challenges: [String] = [], isArchived: Bool = false,
        activeFrom: DayKey? = nil, activeUntil: DayKey? = nil
    ) {
        self.id = id; self.title = title; self.kind = kind; self.difficulty = difficulty
        self.group = group; self.schedule = schedule; self.identity = identity; self.full = full
        self.min = min; self.steps = steps; self.targetMinutes = targetMinutes; self.minMinutes = minMinutes
        self.why = why; self.citations = citations; self.challenges = challenges; self.isArchived = isArchived
        self.activeFrom = activeFrom; self.activeUntil = activeUntil
    }

    public func isActive(on day: DayKey) -> Bool {
        if let from = activeFrom, day < from { return false }
        if let until = activeUntil, day >= until { return false }
        return true
    }

    public func isRequired(on day: DayKey, timeZone: TimeZone = .current) -> Bool {
        isActive(on: day) && schedule.isRequired(on: day, timeZone: timeZone)
    }

    /// Same habit, limited to a date range (nil keeps the current bound).
    public func active(from: DayKey?, until: DayKey?) -> HabitDefinition {
        HabitDefinition(
            id: id, title: title, kind: kind, difficulty: difficulty, group: group, schedule: schedule,
            identity: identity, full: full, min: min, steps: steps, targetMinutes: targetMinutes,
            minMinutes: minMinutes, why: why, citations: citations, challenges: challenges,
            isArchived: until != nil, activeFrom: from ?? activeFrom, activeUntil: until ?? activeUntil
        )
    }
}

public enum CompletionLevel: String, Codable, Sendable {
    case full
    /// The bad-day minimum version. Counts for streaks, pays half.
    case minimum
    /// Explicitly not done (swipe "not done").
    case notDone
    /// Avoid-habit broken (smoked, scrolled). Logged honestly; never counts as done.
    case slipped

    public var countsAsDone: Bool { self == .full || self == .minimum }
}

public enum CompletionSource: String, Codable, Sendable {
    case manual, timer, focus, conorhealth, sleepLog
}

public struct Completion: Codable, Sendable, Hashable {
    public let habitID: String
    public let day: DayKey
    public let level: CompletionLevel
    public let source: CompletionSource
    public let minutes: Int?
    public let stepsDone: [String]

    public init(habitID: String, day: DayKey, level: CompletionLevel, source: CompletionSource = .manual,
                minutes: Int? = nil, stepsDone: [String] = []) {
        self.habitID = habitID; self.day = day; self.level = level
        self.source = source; self.minutes = minutes; self.stepsDone = stepsDone
    }
}

/// Latest completion per habit per day; later entries replace earlier ones.
public struct CompletionIndex: Sendable {
    private let byKey: [String: Completion]

    public init(_ completions: [Completion]) {
        var map: [String: Completion] = [:]
        for completion in completions {
            map[CompletionIndex.key(completion.habitID, completion.day)] = completion
        }
        byKey = map
    }

    public func completion(_ habitID: String, on day: DayKey) -> Completion? {
        byKey[CompletionIndex.key(habitID, day)]
    }

    public func isDone(_ habitID: String, on day: DayKey) -> Bool {
        completion(habitID, on: day)?.level.countsAsDone ?? false
    }

    private static func key(_ id: String, _ day: DayKey) -> String { "\(id)|\(day.rawValue)" }
}

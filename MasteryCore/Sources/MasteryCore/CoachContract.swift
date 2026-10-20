import Foundation

/// CoachSync paths for Conor Mastery (same folder and rules as coach-kb contract v1).
public enum CoachPaths {
    public static let plan = "to-apps/conormastery/plan.json"
    public static let notesDir = "to-apps/conormastery/notes"
    public static let dailyLog = "from-apps/conormastery/daily-log.json"
    public static let conorHealthSessionLogs = "from-apps/conorhealth/session-logs"
}

// MARK: - coach -> app: mastery-plan.v1

public struct MasteryPlan: Codable, Sendable, Hashable {
    public static let formatID = "conor-mastery-plan"

    public let format: String
    public let version: Int
    public let generatedAt: String
    public let weeklyFocus: String?
    public let habits: [PlanHabit]
    public let notes: [String]
    /// Daily-lesson and tip-library content (optional in the file).
    public let lessons: [Lesson]

    public init(generatedAt: String, weeklyFocus: String?, habits: [PlanHabit], notes: [String] = [],
                lessons: [Lesson] = []) {
        format = MasteryPlan.formatID; version = 1
        self.generatedAt = generatedAt; self.weeklyFocus = weeklyFocus; self.habits = habits; self.notes = notes
        self.lessons = lessons
    }

    enum CodingKeys: String, CodingKey {
        case format, version, habits, notes, lessons
        case generatedAt = "generated_at"
        case weeklyFocus = "weekly_focus"
    }

    public func validated() throws -> MasteryPlan {
        guard format == MasteryPlan.formatID else { throw ContractError.wrongFormat(format) }
        guard version == 1 else { throw ContractError.unsupportedVersion(version) }
        let ids = habits.map(\.id)
        guard Set(ids).count == ids.count else { throw ContractError.duplicateHabit }
        return self
    }

    /// Notes and lessons are optional; tolerate their absence.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        format = try c.decode(String.self, forKey: .format)
        version = try c.decode(Int.self, forKey: .version)
        generatedAt = try c.decode(String.self, forKey: .generatedAt)
        weeklyFocus = try c.decodeIfPresent(String.self, forKey: .weeklyFocus)
        habits = try c.decode([PlanHabit].self, forKey: .habits)
        notes = try c.decodeIfPresent([String].self, forKey: .notes) ?? []
        lessons = try c.decodeIfPresent([Lesson].self, forKey: .lessons) ?? []
    }
}

public struct PlanHabit: Codable, Sendable, Hashable {
    public let id: String
    public let title: String
    public let kind: HabitKind
    public let difficulty: Difficulty
    public let group: HabitGroup
    /// "daily", "weekdays:2,3,4,5,6", "every:2", "per-week:3".
    public let schedule: String
    public let identity: String
    public let why: String
    public let full: String
    public let min: String?
    public let steps: [String]?
    public let targetMinutes: Int?
    public let minMinutes: Int?
    public let citations: [Citation]
    public let challenges: [String]

    public init(id: String, title: String, kind: HabitKind, difficulty: Difficulty, group: HabitGroup,
                schedule: String, identity: String, why: String, full: String, min: String? = nil,
                steps: [String]? = nil, targetMinutes: Int? = nil, minMinutes: Int? = nil,
                citations: [Citation] = [], challenges: [String] = []) {
        self.id = id; self.title = title; self.kind = kind; self.difficulty = difficulty; self.group = group
        self.schedule = schedule; self.identity = identity; self.why = why; self.full = full; self.min = min
        self.steps = steps; self.targetMinutes = targetMinutes; self.minMinutes = minMinutes
        self.citations = citations; self.challenges = challenges
    }

    enum CodingKeys: String, CodingKey {
        case id, title, kind, difficulty, group, schedule, identity, why, full, min, steps, citations, challenges
        case targetMinutes = "target_minutes"
        case minMinutes = "min_minutes"
    }

    /// `scheduleChanges` (from the habit editor) keep past days on the schedule they had then.
    public func definition(anchor: DayKey, scheduleChanges: [ScheduleChange] = []) -> HabitDefinition {
        HabitDefinition(
            id: id, title: title, kind: kind, difficulty: difficulty, group: group,
            schedule: HabitEditor.schedule(current: schedule, changes: scheduleChanges, anchor: anchor),
            identity: identity, full: full,
            min: min, steps: steps ?? [], targetMinutes: targetMinutes, minMinutes: minMinutes,
            why: why, citations: citations, challenges: challenges
        )
    }

    /// What the app tracks: a routine becomes one easy habit per step (owner 10-20: missing one step is one miss,
    /// not the whole routine), linked back by `routine`. Ids are `<routine>.<step slug>`, so history follows the
    /// step's text. A routine with no steps stays whole.
    public func definitions(anchor: DayKey, scheduleChanges: [ScheduleChange] = []) -> [HabitDefinition] {
        let whole = definition(anchor: anchor, scheduleChanges: scheduleChanges)
        guard kind == .checklist, !whole.steps.isEmpty else { return [whole] }
        // "Water" and "Water!" share a slug; duplicate ids would trap the strength dictionary on every launch.
        var taken = Set<String>()
        let ids = whole.steps.map { step -> String in
            let base = "\(id).\(Self.slug(step).isEmpty ? "step" : Self.slug(step))"
            var candidate = base, n = 2
            while !taken.insert(candidate).inserted { candidate = "\(base)-\(n)"; n += 1 }
            return candidate
        }
        return whole.steps.enumerated().map { i, step in
            HabitDefinition(id: ids[i], title: step, kind: .build, difficulty: .easy, group: group,
                            schedule: whole.schedule, identity: identity, full: step, why: why,
                            citations: i == 0 ? citations : [], challenges: i == 0 ? challenges : [], routine: id)
        }
    }

    static func slug(_ text: String) -> String {
        text.lowercased().map { $0.isLetter || $0.isNumber ? String($0) : "-" }.joined()
            .split(separator: "-").joined(separator: "-")
    }

    /// Unknown schedule strings fall back to daily (readers stay lenient).
    public static func parseSchedule(_ raw: String, anchor: DayKey) -> Schedule {
        let parts = raw.split(separator: ":", maxSplits: 1).map(String.init)
        switch (parts.first, parts.count > 1 ? parts[1] : nil) {
        case ("weekdays", let list?):
            let days = Set(list.split(separator: ",").compactMap { Int($0) }.filter { (1...7).contains($0) })
            return days.isEmpty ? .daily : .weekdays(days)
        case ("every", let n?):
            return Int(n).map { .everyNDays(n: Swift.max($0, 1), anchor: anchor) } ?? .daily
        case ("per-week", let n?):
            return Int(n).map { .timesPerWeek(Swift.min(Swift.max($0, 1), 7)) } ?? .daily
        default:
            return .daily
        }
    }
}

public enum ContractError: Error, Equatable, Sendable {
    case wrongFormat(String), unsupportedVersion(Int), duplicateHabit
}

// MARK: - app -> coach: mastery-daily-log.v1 (whole file, rewritten)

public struct MasteryDailyLog: Codable, Sendable, Hashable {
    public static let formatID = "conor-mastery-daily-log"

    public let format: String
    public let version: Int
    public let generatedAt: String
    public let days: [LoggedDay]

    public init(generatedAt: String, days: [LoggedDay]) {
        format = MasteryDailyLog.formatID; version = 1
        self.generatedAt = generatedAt; self.days = days.sorted { $0.date < $1.date }
    }

    enum CodingKeys: String, CodingKey {
        case format, version, days
        case generatedAt = "generated_at"
    }
}

public struct LoggedDay: Codable, Sendable, Hashable {
    public let date: DayKey
    public let habits: [LoggedHabit]
    public let sleep: LoggedSleep?
    public let focusMinutes: Int
    public let outcome: DayOutcome?
    public let reflection: String?

    public init(date: DayKey, habits: [LoggedHabit], sleep: LoggedSleep?, focusMinutes: Int,
                outcome: DayOutcome?, reflection: String?) {
        self.date = date; self.habits = habits; self.sleep = sleep
        self.focusMinutes = focusMinutes; self.outcome = outcome; self.reflection = reflection
    }

    enum CodingKeys: String, CodingKey {
        case date, habits, sleep, outcome, reflection
        case focusMinutes = "focus_minutes"
    }
}

public struct LoggedHabit: Codable, Sendable, Hashable {
    public let id: String
    public let status: CompletionLevel
    public let source: CompletionSource
    public let minutes: Int?
}

public struct LoggedSleep: Codable, Sendable, Hashable {
    public let bedtime: ClockTime
    public let wake: ClockTime
    public let hoursInBed: Double
    public let hoursSlept: Double?
    public let quality: Int?
    public let onTarget: Bool

    enum CodingKeys: String, CodingKey {
        case bedtime, wake, quality
        case hoursInBed = "hours_in_bed"
        case hoursSlept = "hours_slept"
        case onTarget = "on_target"
    }
}

public enum DailyLogBuilder {
    /// Unknown is not zero: days with nothing logged are omitted, not written as zeros.
    public static func build(days: [DayKey], completions: [Completion], sleep: [SleepEntry], target: SleepTarget,
                             focusMinutes: [DayKey: Int], outcomes: [DayKey: DayOutcome],
                             reflections: [DayKey: String], generatedAt: String) -> MasteryDailyLog {
        let byDay = Dictionary(grouping: CompletionIndexed.latest(completions), by: \.day)
        let sleepByDay = Dictionary(sleep.map { ($0.wakeDay, $0) }, uniquingKeysWith: { _, last in last })
        let logged: [LoggedDay] = days.compactMap { day in
            let habits = (byDay[day] ?? []).sorted { $0.habitID < $1.habitID }.map {
                LoggedHabit(id: $0.habitID, status: $0.level, source: $0.source, minutes: $0.minutes)
            }
            let night = sleepByDay[day].map {
                LoggedSleep(bedtime: $0.bedtime, wake: $0.wakeTime, hoursInBed: $0.hoursInBed,
                            hoursSlept: $0.hoursSlept, quality: $0.quality, onTarget: target.isOnTarget($0))
            }
            let focus = focusMinutes[day] ?? 0
            guard !habits.isEmpty || night != nil || focus > 0 || reflections[day] != nil else { return nil }
            return LoggedDay(date: day, habits: habits, sleep: night, focusMinutes: focus,
                             outcome: outcomes[day], reflection: reflections[day])
        }
        return MasteryDailyLog(generatedAt: generatedAt, days: logged)
    }
}

enum CompletionIndexed {
    /// Last write wins per habit/day, matching CompletionIndex.
    static func latest(_ completions: [Completion]) -> [Completion] {
        var seen: [String: Completion] = [:]
        for c in completions { seen["\(c.habitID)|\(c.day.rawValue)"] = c }
        return Array(seen.values)
    }
}

// MARK: - ConorHealth link (read-only)

/// The fields Mastery needs from a coach-kb session-log.v1 written by ConorHealth.
public struct ConorHealthSessionLog: Decodable, Sendable, Hashable {
    public let format: String
    public let date: DayKey
    public let durationMin: Int?

    enum CodingKeys: String, CodingKey {
        case format, date
        case durationMin = "duration_min"
    }

    /// ConorHealth logs auto-complete the workout habit. Coach-entered logs count too.
    public func workoutCompletion(habitID: String = "workout") -> Completion? {
        guard format == "coach-kb-session-log" else { return nil }
        return Completion(habitID: habitID, day: date, level: .full, source: .conorhealth, minutes: durationMin)
    }
}

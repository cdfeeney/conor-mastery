import Foundation
import MasteryCore

/// User settings, stored as one JSON blob.
struct AppSettings: Codable, Equatable {
    var startDay: DayKey
    var strictStreak = false
    var sleepTarget = SleepTarget()
    var gate = GateConfig()
    /// Habits the user archived, with the day they stopped counting (history before it is kept).
    var archivedHabits: [String: DayKey] = [:]
    /// First day each plan habit existed; days before it never require the habit.
    var habitFirstSeen: [String: DayKey] = [:]
    /// Habits the coach dropped from the plan: kept so past days are still judged fairly.
    var retiredHabits: [RetiredHabit] = []
    /// Day the daily challenge was completed (pays once).
    var challengeDoneDay: DayKey?
    /// Paid unblock end time.
    var unblockUntil: Date?
    /// Locked-in focus end time (the monitor reads it through the gate snapshot).
    var lockedInUntil: Date?
    var soundOn = true
    /// When/where per habit (implementation intentions).
    var habitPlans: [String: HabitPlan] = [:]
    /// Rest days (sick, travel): nothing required; streak, strength and energy pause. Max 3 a month.
    var restDays: Set<DayKey> = []
    /// Real-life rewards priced in grit.
    var treats: [Treat] = []
    /// Daily-lesson answers by lesson id (kept, or missed and due for review).
    var lessons: [String: LessonRecord] = [:]
    /// Lessons you made into rules: shown on the habit page and in tonight's check.
    var pinnedRules: [String] = []

    static func fresh(today: DayKey) -> AppSettings { AppSettings(startDay: today) }

    init(startDay: DayKey) { self.startDay = startDay }

    /// Lenient decode: a field added in a later version must never reset the player's history.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        startDay = try c.decode(DayKey.self, forKey: .startDay)
        strictStreak = try c.decodeIfPresent(Bool.self, forKey: .strictStreak) ?? false
        sleepTarget = try c.decodeIfPresent(SleepTarget.self, forKey: .sleepTarget) ?? SleepTarget()
        gate = try c.decodeIfPresent(GateConfig.self, forKey: .gate) ?? GateConfig()
        archivedHabits = try c.decodeIfPresent([String: DayKey].self, forKey: .archivedHabits) ?? [:]
        habitFirstSeen = try c.decodeIfPresent([String: DayKey].self, forKey: .habitFirstSeen) ?? [:]
        retiredHabits = try c.decodeIfPresent([RetiredHabit].self, forKey: .retiredHabits) ?? []
        challengeDoneDay = try c.decodeIfPresent(DayKey.self, forKey: .challengeDoneDay)
        unblockUntil = try c.decodeIfPresent(Date.self, forKey: .unblockUntil)
        lockedInUntil = try c.decodeIfPresent(Date.self, forKey: .lockedInUntil)
        soundOn = try c.decodeIfPresent(Bool.self, forKey: .soundOn) ?? true
        habitPlans = try c.decodeIfPresent([String: HabitPlan].self, forKey: .habitPlans) ?? [:]
        restDays = try c.decodeIfPresent(Set<DayKey>.self, forKey: .restDays) ?? []
        treats = try c.decodeIfPresent([Treat].self, forKey: .treats) ?? []
        lessons = try c.decodeIfPresent([String: LessonRecord].self, forKey: .lessons) ?? [:]
        pinnedRules = try c.decodeIfPresent([String].self, forKey: .pinnedRules) ?? []
    }
}

struct RetiredHabit: Codable, Equatable {
    let habit: PlanHabit
    let until: DayKey
}

enum BlobKey {
    static let drafts = "drafts.v1"
    static let settings = "settings.v1"
    static let world = "world.v1"
    static let plan = "plan.v1"
}

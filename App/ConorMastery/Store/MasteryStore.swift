import Foundation
import Observation
import SwiftData
import MasteryCore

/// The single owner of app state. Views read derived values; every change goes through an action
/// in MasteryStore+Actions.swift, which computes the next value with MasteryCore and persists it.
@MainActor @Observable
final class MasteryStore {
    let context: ModelContext
    let timeZone = TimeZone.current

    private(set) var settings: AppSettings
    private(set) var plan: MasteryPlan
    private(set) var state: MasteryState
    var sleep: [SleepEntry] = []
    var focus: [FocusSession] = []
    private(set) var world = WorldState()
    private(set) var tasks: [TaskRecord] = []
    var reflections: [DayKey: String] = [:]
    /// Checklist ticks before the habit is complete, keyed "habitID|YYYY-MM-DD" (persisted).
    var drafts: [String: [String]] = [:]
    /// Last reward, shown as a toast.
    var lastReward: RewardToast?
    var errorMessage: String?

    init(context: ModelContext) {
        self.context = context
        let today = DayKey(date: .now)
        let settings = Self.loadBlob(AppSettings.self, key: BlobKey.settings, context: context) ?? .fresh(today: today)
        let plan = Self.loadBlob(MasteryPlan.self, key: BlobKey.plan, context: context) ?? SeedPlan.load()
        self.settings = settings
        self.plan = plan
        self.state = MasteryState(habits: [], completions: [], ledger: GritLedger(), startDay: settings.startDay)
        reload()
    }

    // MARK: - Derived

    var today: DayKey { DayKey(date: .now, timeZone: timeZone) }
    /// Habits shown and required today. `state.habits` also holds archived/retired ones for history.
    var habits: [HabitDefinition] { state.habits.filter { $0.isActive(on: today) } }

    /// Strength as of the start of today (drives price, plant tier and drop chance).
    var strength: [String: Double] { state.strength(on: today) }
    func tier(_ habitID: String) -> HabitTier { StrengthRules.tier(strength[habitID] ?? 0) }
    func multiplier(_ habitID: String) -> Double { StrengthRules.multiplier(strength[habitID] ?? 0) }
    var energy: EnergyState { state.energy(on: today) }
    var isRestDay: Bool { settings.restDays.contains(today) }

    func draftSteps(_ habitID: String) -> [String] { drafts[Self.draftKey(habitID, today)] ?? [] }

    static func draftKey(_ habitID: String, _ day: DayKey) -> String { "\(habitID)|\(day.rawValue)" }
    var streak: StreakState { state.streak(through: today) }
    var level: LevelProgress { state.ledger.level }
    var grit: Int { state.ledger.balance }
    var index: CompletionIndex { CompletionIndex(state.completions) }

    func habits(in group: HabitGroup) -> [HabitDefinition] { habits.filter { $0.group == group } }

    func completion(_ habitID: String, on day: DayKey? = nil) -> Completion? {
        index.completion(habitID, on: day ?? today)
    }

    var requiredToday: [HabitDefinition] { habits.filter { $0.isRequired(on: today, timeZone: timeZone) } }
    var doneTodayCount: Int { requiredToday.filter { index.isDone($0.id, on: today) }.count }
    var focusMinutesToday: Int { FocusEngine.minutes(on: today, sessions: focus) }
    var gritEarnedToday: Int { state.ledger.earned(on: today) }

    var challenge: DailyChallenge? {
        ChallengePicker.pick(habits: habits, completions: state.completions, today: today, timeZone: timeZone)
    }
    var challengeDone: Bool { settings.challengeDoneDay == today }

    /// Today's coach lesson (stays put all day once answered).
    var lesson: Lesson? {
        LessonPlanner.pick(plan.lessons, records: settings.lessons, habitOrder: plan.habits.map(\.id),
                           today: today, timeZone: timeZone)
    }

    var lessonAnswer: LessonRecord? {
        lesson.flatMap { settings.lessons[$0.id] }.flatMap { $0.lastAnswered == today ? $0 : nil }
    }

    var pinnedLessons: [Lesson] { plan.lessons.filter { settings.pinnedRules.contains($0.id) } }

    /// Last 7 days for a habit's dot strip, oldest first.
    func weekStrip(_ habitID: String) -> [Completion?] {
        (0..<7).reversed().map { index.completion(habitID, on: today.adding(days: -$0, timeZone: timeZone)) }
    }

    func cleanDays(_ habitID: String) -> Int {
        CleanStreak.daysClean(habitID: habitID, since: settings.startDay, through: today,
                              completions: state.completions, timeZone: timeZone)
    }

    var sleepStats: SleepStats? {
        let cutoff = today.adding(days: -7, timeZone: timeZone)
        return SleepStats.compute(sleep.filter { $0.wakeDay > cutoff }, target: settings.sleepTarget)
    }

    var consistency: [HabitConsistency] {
        ConsistencyReport.weakest(ConsistencyReport.compute(habits: habits, completions: state.completions,
                                                            today: today, timeZone: timeZone))
    }

    /// The morning gate opens when its habit is done, or when it isn't required today (edited to weekdays,
    /// switched off, or dropped by the coach), so apps can never stay locked with nothing to complete.
    var morningGateMet: Bool {
        let id = settings.gate.morningHabitID
        guard let habit = habits.first(where: { $0.id == id }), habit.isRequired(on: today, timeZone: timeZone) else { return true }
        return index.isDone(id, on: today)
    }

    func gateDecision(now: Date = .now, lockedInActive: Bool = false) -> ShieldDecision {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: now)
        let clock = ClockTime(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
        let unblock = settings.unblockUntil.map { $0 > now } ?? false
        let lockedIn = lockedInActive || (settings.lockedInUntil.map { $0 > now } ?? false)
        return GatePolicy.decide(config: settings.gate, now: clock,
                                 morningDone: morningGateMet,
                                 lockedInActive: lockedIn, unblockActive: unblock)
    }

    // MARK: - Loading

    func reload() {
        let completions = fetch(SortDescriptor(\CompletionRecord.createdAt)).compactMap(Self.completion)
        let ledger = GritLedger(fetch(SortDescriptor(\LedgerRecord.createdAt)).compactMap(Self.transaction))
        stampFirstSeen()
        state = MasteryState(habits: habitDefinitions(), completions: completions, ledger: ledger,
                             startDay: settings.startDay, strictStreak: settings.strictStreak,
                             restDays: settings.restDays, timeZone: timeZone)
        sleep = fetch(SortDescriptor(\SleepRecord.wakeDay)).compactMap(Self.sleepEntry)
        focus = fetch(SortDescriptor(\FocusRecord.createdAt)).compactMap(Self.focusSession)
        world = Self.loadBlob(WorldState.self, key: BlobKey.world, context: context) ?? WorldState()
        drafts = Self.loadBlob([String: [String]].self, key: BlobKey.drafts, context: context) ?? [:]
        tasks = fetch(SortDescriptor(\TaskRecord.day))
        reflections = Dictionary(fetch(SortDescriptor(\ReflectionRecord.day)).compactMap { r in
            DayKey(r.day).map { ($0, r.text) }
        }, uniquingKeysWith: { _, last in last })
    }

    func fetch<T: PersistentModel>(_ sort: SortDescriptor<T>) -> [T] {
        do {
            return try context.fetch(FetchDescriptor<T>(sortBy: [sort]))
        } catch {
            errorMessage = "Couldn't read saved data: \(error.localizedDescription)"
            return []
        }
    }

    // MARK: - Persistence helpers (used by actions)

    func save() {
        do { try context.save() } catch { errorMessage = "Couldn't save: \(error.localizedDescription)" }
    }

    func saveBlob(_ value: some Encodable, key: String) {
        do {
            let data = try JSONEncoder().encode(value)
            let existing = try context.fetch(FetchDescriptor<BlobRecord>(predicate: #Predicate { $0.key == key }))
            if let record = existing.first { record.data = data } else { context.insert(BlobRecord(key: key, data: data)) }
        } catch {
            errorMessage = "Couldn't save \(key): \(error.localizedDescription)"
        }
    }

    func update(settings next: AppSettings) {
        settings = next
        saveBlob(next, key: BlobKey.settings)
        save()
        reload()
    }

    /// Coach habits with your edits, then your own habits: what the app actually tracks.
    var effectivePlanHabits: [PlanHabit] {
        HabitEditor.effective(plan: plan.habits, edits: settings.habitEdits, custom: settings.customHabits)
    }

    /// Habits the new plan drops are retired (kept for history) rather than deleted.
    func replace(plan next: MasteryPlan) {
        let newIDs = Set(next.habits.map(\.id))
        var s = settings
        let dropped = plan.habits.filter { !newIDs.contains($0.id) }.map { s.habitEdits[$0.id] ?? $0 }
        s.habitEdits = s.habitEdits.filter { newIDs.contains($0.key) }
        s.retiredHabits = s.retiredHabits.filter { !newIDs.contains($0.habit.id) }
            + dropped.map { RetiredHabit(habit: $0, until: today) }
        settings = s
        saveBlob(s, key: BlobKey.settings)
        plan = next
        saveBlob(next, key: BlobKey.plan)
        save()
        reload()
    }

    /// Current plan habits (with first-seen / archived ranges) plus retired ones, for honest history.
    func habitDefinitions() -> [HabitDefinition] {
        let current = effectivePlanHabits.map { habit -> HabitDefinition in
            let def = habit.definition(anchor: settings.startDay, scheduleChanges: settings.scheduleChanges[habit.id] ?? [])
            let from = settings.habitFirstSeen[habit.id].flatMap { $0 > settings.startDay ? $0 : nil }
            return def.active(from: from, until: settings.archivedHabits[habit.id])
        }
        let retired = settings.retiredHabits.map {
            $0.habit.definition(anchor: settings.startDay, scheduleChanges: settings.scheduleChanges[$0.habit.id] ?? []).active(from: settings.habitFirstSeen[$0.habit.id], until: $0.until)
        }
        return current + retired
    }

    /// Records the first day each plan habit appeared (once).
    func stampFirstSeen() {
        let missing = effectivePlanHabits.map(\.id).filter { settings.habitFirstSeen[$0] == nil }
        guard !missing.isEmpty else { return }
        var s = settings
        for id in missing { s.habitFirstSeen[id] = today }
        settings = s
        saveBlob(s, key: BlobKey.settings)
        save()
    }

    func setLockedIn(until: Date?) {
        var s = settings
        s.lockedInUntil = until
        update(settings: s)
    }

    func saveDrafts() { saveBlob(drafts, key: BlobKey.drafts) }

    func replace(world next: WorldState) {
        world = next
        saveBlob(next, key: BlobKey.world)
    }

    /// Persists ledger entries added since `old` (the ledger is append-only).
    func persistLedgerTail(from old: GritLedger, to new: GritLedger) {
        for tx in new.transactions.dropFirst(old.transactions.count) {
            context.insert(LedgerRecord(id: tx.id, day: tx.day.rawValue, amount: tx.amount,
                                        reason: tx.reason.rawValue, ref: tx.ref, xp: tx.xp))
        }
    }

    func setState(_ next: MasteryState) { state = next }

    static func loadBlob<T: Decodable>(_ type: T.Type, key: String, context: ModelContext) -> T? {
        let records = try? context.fetch(FetchDescriptor<BlobRecord>(predicate: #Predicate { $0.key == key }))
        guard let data = records?.first?.data else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

struct RewardToast: Equatable, Identifiable {
    let id = UUID()
    let title: String
    let reward: Reward
    var drop: Drop? = nil
}

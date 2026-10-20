import MasteryCore
import SwiftData
import XCTest
@testable import ConorMastery

/// Store-level checks against an in-memory SwiftData container: actions persist and reload intact.
@MainActor
final class StoreTests: XCTestCase {
    /// Held for the whole test: a freed ModelContainer makes every later context call trap
    /// (the same trap ConorHealth hit; the real app keeps its container in ConorMasteryApp).
    /// XCTest makes a new instance per test case, so each test gets its own container.
    private var container: ModelContainer?

    private func makeStore() throws -> MasteryStore {
        let made = try ModelContainer(for: Schema(Schema1.models),
                                      configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        container = made
        return MasteryStore(context: made.mainContext)
    }

    func testSeedPlanShipsAllNineHabits() throws {
        let store = try makeStore()
        XCTAssertEqual(store.plan.habits.count, 9, store.plan.notes.joined())
    }

    func testLogPersistsAcrossReload() throws {
        let store = try makeStore()
        let habit = try XCTUnwrap(store.habits.first { $0.kind == .build || $0.kind == .checklist })
        store.log(.full, habitID: habit.id)
        let grit = store.grit
        XCTAssertGreaterThan(grit, 0)
        store.reload()
        XCTAssertEqual(store.grit, grit)
        XCTAssertEqual(store.completion(habit.id)?.level, .full)
    }

    func testUndoRefundsAndRemovesCompletion() throws {
        let store = try makeStore()
        let habit = try XCTUnwrap(store.habits.first)
        store.log(.full, habitID: habit.id)
        store.clear(habitID: habit.id)
        store.reload()
        XCTAssertEqual(store.grit, 0)
        XCTAssertNil(store.completion(habit.id))
    }

    func testSleepLogCompletesSleepHabit() throws {
        let store = try makeStore()
        let entry = SleepEntry(wakeDay: store.today, bedtime: ClockTime(hour: 22, minute: 30), wakeTime: ClockTime(hour: 6, minute: 30))
        store.logSleep(entry)
        let sleepHabit = try XCTUnwrap(store.habits.first { $0.kind == .sleep })
        XCTAssertEqual(store.completion(sleepHabit.id)?.level, .full)
        store.reload()
        XCTAssertEqual(store.sleep.count, 1)
    }

    func testBuyingNeedsGrit() throws {
        let store = try makeStore()
        store.buy(try XCTUnwrap(Catalog.item("bamboo")))
        XCTAssertNotNil(store.errorMessage)
        XCTAssertEqual(store.world.inventory["bamboo"] ?? 0, 0)
    }

    func testLessonKeptPaysOnceAndStaysTodaysLesson() throws {
        let store = try makeStore()
        let lesson = try XCTUnwrap(store.lesson, "seed plan ships lessons")
        store.answerLesson(kept: true)
        store.answerLesson(kept: true)
        XCTAssertEqual(store.grit, RewardRules.lessonGrit)
        store.reload()
        XCTAssertEqual(store.lesson?.id, lesson.id)
        XCTAssertEqual(store.lessonAnswer?.status, .kept)
    }

    func testPinnedRuleTogglesAndPersists() throws {
        let store = try makeStore()
        let lesson = try XCTUnwrap(store.lesson)
        store.togglePinned(lesson.id)
        store.reload()
        XCTAssertEqual(store.pinnedLessons.map(\.id), [lesson.id])
        store.togglePinned(lesson.id)
        XCTAssertTrue(store.pinnedLessons.isEmpty)
    }

    func testHabitEditWinsAndResetRestoresCoachVersion() throws {
        let store = try makeStore()
        let coach = try XCTUnwrap(store.effectivePlanHabits.first { $0.kind == .build || $0.kind == .avoid })
        store.saveHabit(coach.edited(title: "My version", full: coach.full, min: nil, group: .night, difficulty: .easy,
                                     schedule: .perWeek(3), steps: nil, targetMinutes: nil, minMinutes: nil))
        store.reload()
        XCTAssertEqual(store.habits.first { $0.id == coach.id }?.title, "My version")
        store.resetHabit(coach.id)
        XCTAssertEqual(store.habits.first { $0.id == coach.id }?.title, coach.title)
    }

    func testCustomHabitAddsThenDeleteKeepsHistory() throws {
        let store = try makeStore()
        let mine = HabitEditor.newCustom(title: "Read", kind: .build, group: .night, full: "10 pages",
                                         existingIDs: Set(store.effectivePlanHabits.map(\.id)))
        store.addCustomHabit(mine)
        store.log(.full, habitID: mine.id)
        XCTAssertNotNil(store.completion(mine.id))
        store.deleteCustomHabit(mine.id)
        store.reload()
        XCTAssertFalse(store.effectivePlanHabits.contains { $0.id == mine.id })
        XCTAssertTrue(store.settings.retiredHabits.contains { $0.habit.id == mine.id })
        XCTAssertGreaterThan(store.grit, 0, "grit earned on the deleted habit stays")
    }

    func testFreshInstallUsesThePlansFocusUntilThereIsHistory() throws {
        let store = try makeStore()
        XCTAssertNil(store.advice)
        XCTAssertEqual(store.weeklyFocus, store.plan.weeklyFocus)
    }

    func testWeeklyHabitCountsTowardItsTargetNotTheDailyList() throws {
        let store = try makeStore()
        let draft = HabitEditor.newCustom(title: "Gym", kind: .build, group: .day, full: "Lift",
                                          existingIDs: Set(store.effectivePlanHabits.map(\.id)))
        let gym = draft.edited(title: "Gym", full: "Lift", min: nil, group: .day, difficulty: .medium,
                               schedule: .perWeek(3), steps: nil, targetMinutes: nil, minMinutes: nil)
        store.addCustomHabit(gym)
        let habit = try XCTUnwrap(store.habits.first { $0.id == gym.id })
        XCTAssertFalse(store.requiredToday.contains { $0.id == gym.id })
        store.log(.full, habitID: gym.id)
        XCTAssertEqual(store.weeklyProgress(habit)?.done, 1)
        // Added today, so this first week's target is capped by the days left (e.g. 2 on a Saturday).
        let progress = try XCTUnwrap(store.weeklyProgress(habit))
        XCTAssertEqual(progress.target, min(3, progress.daysLeft))
    }

    func testWidgetSnapshotShowsTodayWithOpenHabitsFirst() throws {
        let store = try makeStore()
        let habit = try XCTUnwrap(store.requiredToday.first { $0.kind == .build || $0.kind == .avoid })
        store.log(.full, habitID: habit.id)
        let snapshot = WidgetPublisher.makeSnapshot(store)
        XCTAssertEqual(snapshot.day, store.today.rawValue)
        XCTAssertEqual(snapshot.done, 1)
        XCTAssertEqual(snapshot.required, store.requiredToday.count)
        XCTAssertEqual(snapshot.items.last?.title, habit.title)
        XCTAssertFalse(snapshot.items.first?.isDone ?? true)
        let tomorrow = snapshot.asOf("2999-01-01")
        XCTAssertTrue(tomorrow.isNewDay)
        XCTAssertTrue(tomorrow.items.isEmpty)
        XCTAssertEqual(tomorrow.streak, snapshot.streak)
    }

    /// Codex review 10-20: an install that tracked the routine whole keeps those days judged by the whole routine.
    func testWholeRoutineKeepsJudgingDaysBeforeTheSplit() throws {
        let store = try makeStore()
        let weekAgo = store.today.adding(days: -7, timeZone: store.timeZone)
        var s = store.settings
        s.startDay = weekAgo
        s.habitFirstSeen["morning-routine"] = weekAgo
        store.update(settings: s)
        let legacy = try XCTUnwrap(store.state.habits.first { $0.id == "morning-routine" })
        XCTAssertEqual(legacy.activeUntil, store.today)
        XCTAssertTrue(legacy.isRequired(on: weekAgo, timeZone: store.timeZone))
        XCTAssertFalse(store.habits.contains { $0.id == "morning-routine" })
    }

    /// Owner 10-20: each routine step is its own habit; the morning gate opens only when every step is done.
    func testRoutineStepsAreSeparateHabitsAndGateTheMorning() throws {
        let store = try makeStore()
        let steps = store.habits.filter { $0.routine == store.settings.gate.morningHabitID }
        XCTAssertEqual(steps.count, 6)
        XCTAssertEqual(store.habits.filter { $0.routine == "night-routine" }.count, 6)
        XCTAssertFalse(store.habits.contains { $0.id == "morning-routine" })
        store.log(.full, habitID: steps[0].id)
        XCTAssertNil(store.completion(steps[1].id))
        XCTAssertFalse(store.morningGateMet)
        for step in steps.dropFirst() { store.log(.full, habitID: step.id) }
        XCTAssertTrue(store.morningGateMet)
        XCTAssertEqual(store.planHabits.filter { $0.id.hasSuffix("-routine") }.count, 2)
    }
}

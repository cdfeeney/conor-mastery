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
        XCTAssertEqual(store.weeklyProgress(habit)?.target, 3)
    }

    func testChecklistCompletesOnLastStep() throws {
        let store = try makeStore()
        let routine = try XCTUnwrap(store.habits.first { $0.kind == .checklist && !$0.steps.isEmpty })
        for step in routine.steps { store.toggleStep(step, habit: routine) }
        XCTAssertEqual(store.completion(routine.id)?.level, .full)
        store.toggleStep(routine.steps[0], habit: routine)
        XCTAssertNil(store.completion(routine.id))
    }
}

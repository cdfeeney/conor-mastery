import MasteryCore
import SwiftData
import XCTest
@testable import ConorMastery

/// Store-level checks against an in-memory SwiftData container: actions persist and reload intact.
@MainActor
final class StoreTests: XCTestCase {
    private func makeStore() throws -> MasteryStore {
        let container = try ModelContainer(for: Schema(Schema1.models),
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return MasteryStore(context: container.mainContext)
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

    func testChecklistCompletesOnLastStep() throws {
        let store = try makeStore()
        let routine = try XCTUnwrap(store.habits.first { $0.kind == .checklist && !$0.steps.isEmpty })
        for step in routine.steps { store.toggleStep(step, habit: routine) }
        XCTAssertEqual(store.completion(routine.id)?.level, .full)
        store.toggleStep(routine.steps[0], habit: routine)
        XCTAssertNil(store.completion(routine.id))
    }
}

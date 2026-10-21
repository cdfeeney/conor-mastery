import Testing
@testable import MasteryCore

/// Owner 10-21: a GitHub-style grid of every habit, and the streak's minimum visible on Today.
@Suite struct HistoryGridTests {
    let start = day("2026-10-01")
    let today = day("2026-10-21")  // a Wednesday

    func mark(_ habits: [HabitDefinition], _ raw: String, _ completions: [Completion], rest: Set<DayKey> = []) -> HistoryMark {
        HabitHistory.mark(habits, on: day(raw), today: today, start: start, index: CompletionIndex(completions),
                          restDays: rest, timeZone: utc)
    }

    @Test func singleHabitMarksEachLevel() {
        let walk = habit("walk")
        #expect(mark([walk], "2026-10-10", [done("walk", "2026-10-10")]) == .full)
        #expect(mark([walk], "2026-10-10", [done("walk", "2026-10-10", .minimum)]) == .minimum)
        #expect(mark([walk], "2026-10-10", [done("walk", "2026-10-10", .slipped)]) == .slipped)
        #expect(mark([walk], "2026-10-10", [done("walk", "2026-10-10", .notDone)]) == .missed)
        #expect(mark([walk], "2026-10-10", []) == .missed)
    }

    @Test func todayIsOpenNotMissed() {
        #expect(mark([habit("walk")], "2026-10-21", []) == .open)
    }

    @Test func beforeStartAfterTodayAndRestDaysAreBlank() {
        let walk = habit("walk")
        #expect(mark([walk], "2026-09-30", []) == .beforeStart)
        #expect(mark([walk], "2026-10-22", []) == .future)
        #expect(mark([walk], "2026-10-10", [], rest: [day("2026-10-10")]) == .off)
    }

    @Test func routineStepsAggregate() {
        let a = habit("r.a"), b = habit("r.b")
        #expect(mark([a, b], "2026-10-10", [done("r.a", "2026-10-10"), done("r.b", "2026-10-10")]) == .full)
        #expect(mark([a, b], "2026-10-10", [done("r.a", "2026-10-10"), done("r.b", "2026-10-10", .minimum)]) == .minimum)
        #expect(mark([a, b], "2026-10-10", [done("r.a", "2026-10-10")]) == .partial)
        #expect(mark([a, b], "2026-10-21", [done("r.a", "2026-10-21")]) == .partial)
    }

    @Test func unscheduledDayShowsOnlyWhatWasDone() {
        let weekly = habit("gym", schedule: .timesPerWeek(3))
        #expect(mark([weekly], "2026-10-10", []) == .off)
        #expect(mark([weekly], "2026-10-10", [done("gym", "2026-10-10")]) == .full)
    }

    /// Codex review 10-21: a weekly routine with one step done is partial, not full.
    @Test func unscheduledRoutineNeedsEveryStep() {
        let a = habit("r.a", schedule: .timesPerWeek(2)), b = habit("r.b", schedule: .timesPerWeek(2))
        #expect(mark([a, b], "2026-10-10", [done("r.a", "2026-10-10")]) == .partial)
        #expect(mark([a, b], "2026-10-10", [done("r.a", "2026-10-10"), done("r.b", "2026-10-10")]) == .full)
    }

    /// Codex review 10-21: a slip on a habit not required that day doesn't spoil the others.
    @Test func optionalSlipDoesNotTurnARequiredDayRed() {
        let walk = habit("walk"), smoke = habit("smoke", schedule: .timesPerWeek(1), kind: .avoid)
        #expect(mark([walk, smoke], "2026-10-10", [done("walk", "2026-10-10"), done("smoke", "2026-10-10", .slipped)]) == .full)
    }

    @Test func habitNotYetActiveIsBlank() {
        let late = habit("late").active(from: day("2026-10-15"), until: nil)
        #expect(mark([late], "2026-10-12", []) == .off)
    }

    @Test func weeksEndOnTodaysColumnAndRunSundayToSaturday() {
        let weeks = HabitHistory.weeks(endingOn: today, count: 3, timeZone: utc)
        #expect(weeks.count == 3)
        #expect(weeks.allSatisfy { $0.count == 7 })
        #expect(weeks[0][0] == day("2026-10-04"))  // Sunday two weeks back
        #expect(weeks[2][3] == today)              // Wednesday
        #expect(weeks[2][4] == nil)                // Thursday is in the future
    }

    @Test func streakKeeperListsOpenRequiredHabitsOnly() {
        let walk = habit("walk"), read = habit("read"), gym = habit("gym", schedule: .timesPerWeek(3))
        let open = StreakKeeper.open([walk, read, gym], index: CompletionIndex([done("walk", "2026-10-21", .minimum)]),
                                     on: today, timeZone: utc)
        #expect(open.map(\.id) == ["read"])
    }
}

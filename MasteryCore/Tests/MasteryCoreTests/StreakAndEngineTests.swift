import Testing
@testable import MasteryCore

@Suite struct StreakTests {
    let habits = [habit("a"), habit("b")]

    func perfectDays(_ count: Int, from start: String) -> [Completion] {
        DayKey.range(day(start), through: day(start).adding(days: count - 1, timeZone: utc), timeZone: utc)
            .flatMap { [Completion(habitID: "a", day: $0, level: .full), Completion(habitID: "b", day: $0, level: .minimum)] }
    }

    @Test func minimumCountsTowardPerfectDay() {
        let state = StreakEngine(timeZone: utc).evaluate(from: day("2026-10-01"), through: day("2026-10-03"),
                                                         habits: habits, completions: perfectDays(3, from: "2026-10-01"))
        #expect(state.current == 3)
    }

    @Test func unfinishedTodayIsPendingNotMissed() {
        let state = StreakEngine(timeZone: utc).evaluate(from: day("2026-10-01"), through: day("2026-10-03"),
                                                         habits: habits, completions: perfectDays(2, from: "2026-10-01"))
        #expect(state.current == 2)
        #expect(state.outcomes[day("2026-10-03")] == .pending)
    }

    @Test func missWithoutTokenResetsStreak() {
        let completions = perfectDays(3, from: "2026-10-01") + perfectDays(1, from: "2026-10-05")
        let state = StreakEngine(timeZone: utc).evaluate(from: day("2026-10-01"), through: day("2026-10-05"),
                                                         habits: habits, completions: completions)
        #expect(state.outcomes[day("2026-10-04")] == .missed)
        #expect(state.current == 1)
        #expect(state.best == 3)
    }

    @Test func sevenPerfectDaysEarnASecondWindThatSavesAMiss() {
        let completions = perfectDays(7, from: "2026-10-01") + perfectDays(1, from: "2026-10-09")
        let state = StreakEngine(timeZone: utc).evaluate(from: day("2026-10-01"), through: day("2026-10-09"),
                                                         habits: habits, completions: completions)
        #expect(state.outcomes[day("2026-10-08")] == .saved)
        #expect(state.current == 8)
        #expect(state.secondWinds == 0)
    }

    @Test func strictModeHasNoSecondWinds() {
        let completions = perfectDays(7, from: "2026-10-01") + perfectDays(1, from: "2026-10-09")
        let state = StreakEngine(strict: true, timeZone: utc).evaluate(from: day("2026-10-01"), through: day("2026-10-09"),
                                                                       habits: habits, completions: completions)
        #expect(state.current == 1)
    }

    @Test func tokensCapAtTwo() {
        let state = StreakEngine(timeZone: utc).evaluate(from: day("2026-10-01"), through: day("2026-10-28"),
                                                         habits: habits, completions: perfectDays(28, from: "2026-10-01"))
        #expect(state.secondWinds == 2)
    }

    @Test func daysWithNothingRequiredAreRestAndKeepTheStreak() {
        let weekdayOnly = [habit("a", schedule: .weekdays([2, 3, 4, 5, 6]))]
        // 2026-10-02 is a Friday, 03/04 weekend, 05 Monday.
        let completions = [done("a", "2026-10-02"), done("a", "2026-10-05")]
        let state = StreakEngine(timeZone: utc).evaluate(from: day("2026-10-02"), through: day("2026-10-05"),
                                                         habits: weekdayOnly, completions: completions)
        #expect(state.outcomes[day("2026-10-03")] == .rest)
        #expect(state.current == 2)
    }

    @Test func cleanStreakCountsFromLastSlip() {
        let completions = [Completion(habitID: "nicotine", day: day("2026-10-03"), level: .slipped),
                           done("nicotine", "2026-10-10")]
        let clean = CleanStreak.daysClean(habitID: "nicotine", since: day("2026-10-01"), through: day("2026-10-10"),
                                          completions: completions, timeZone: utc)
        #expect(clean == 7) // 04..10 inclusive, today confirmed
    }
}

@Suite struct EngineTests {
    let start = day("2026-10-01")

    func state(_ habits: [HabitDefinition] = [habit("a", .hard)]) -> MasteryState {
        MasteryState(habits: habits, completions: [], ledger: GritLedger(), startDay: start, timeZone: utc)
    }

    @Test func togglingTheSameDayNeverFarmsGrit() {
        var s = state()
        for _ in 0..<5 {
            s = MasteryEngine.log(.full, habitID: "a", day: start, in: s).state
            s = MasteryEngine.clear(habitID: "a", day: start, in: s).state
        }
        s = MasteryEngine.log(.full, habitID: "a", day: start, in: s).state
        #expect(s.ledger.balance == 15)
        #expect(s.ledger.totalXP == 10)
    }

    @Test func downgradingToMinimumRefundsTheDifference() {
        var s = MasteryEngine.log(.full, habitID: "a", day: start, in: state()).state
        let result = MasteryEngine.log(.minimum, habitID: "a", day: start, in: s)
        s = result.state
        #expect(result.delta.grit == -7)
        #expect(s.ledger.balance == 8)
        #expect(s.ledger.totalXP == 10)
    }

    @Test func unknownHabitIsIgnored() {
        let result = MasteryEngine.log(.full, habitID: "nope", day: start, in: state())
        #expect(result.delta == .zero && result.state.completions.isEmpty)
    }

    @Test func streakBonusUsesYesterdaysStreak() {
        var s = state([habit("a", .easy)])
        for offset in 0..<7 {
            s = MasteryEngine.log(.full, habitID: "a", day: start.adding(days: offset, timeZone: utc), in: s).state
        }
        let eighth = MasteryEngine.log(.full, habitID: "a", day: start.adding(days: 7, timeZone: utc), in: s)
        #expect(eighth.delta.grit == 6) // 5 base + 1 week bonus
    }
}

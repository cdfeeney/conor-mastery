import Testing
@testable import MasteryCore

/// The Dojo's "+N grit" must match what the screens show (gate run 39314550527: +39 vs habits summing 24).
@Suite struct EarnedTodayTests {
    let today = day("2026-10-19")

    @Test func undoneHabitAndSpendingDoNotCountAsEarned() {
        let ledger = GritLedger([
            GritTransaction(day: today, amount: 10, reason: .habit, ref: "read@2026-10-19"),
            GritTransaction(day: today, amount: -10, reason: .refund, ref: "read@2026-10-19"),
            GritTransaction(day: today, amount: 6, reason: .habit, ref: "walk@2026-10-19"),
            GritTransaction(day: today, amount: 3, reason: .focus, ref: "focus@a"),
            GritTransaction(day: today, amount: -20, reason: .purchase, ref: "lantern"),
            GritTransaction(day: day("2026-10-18"), amount: 50, reason: .habit, ref: "walk@2026-10-18"),
        ])
        #expect(ledger.earned(on: today) == 9)
        let sources = ledger.earnedBySource(on: today)
        #expect(sources.map(\.source) == [.habits, .focus])
        #expect(sources.map(\.grit) == [6, 3])
    }

    @Test func habitCardsAddUpToTheDojoTotalAfterADowngrade() {
        let first = day("2026-10-01")
        var s = MasteryState(habits: [habit("a", .hard), habit("b"), habit("c", .easy)], completions: [],
                             ledger: GritLedger(), startDay: first, timeZone: utc)
        for id in ["a", "b", "c"] { s = MasteryEngine.log(.full, habitID: id, day: first, in: s).state }
        s = MasteryEngine.log(.minimum, habitID: "a", day: first, in: s).state
        let paid = ["a", "b", "c"].map { MasteryEngine.paidReward(habitID: $0, day: first, ledger: s.ledger).grit }
        #expect(paid.reduce(0, +) == s.ledger.earned(on: first))
    }
}

import Testing
@testable import MasteryCore

@Suite struct StrengthTests {
    let h = habit("a", .medium)
    func days(_ n: Int, from raw: String = "2026-10-01") -> [DayKey] {
        DayKey.range(day(raw), through: day(raw).adding(days: n - 1, timeZone: utc), timeZone: utc)
    }

    @Test func doingRaisesMissingLowers() {
        let done = days(10).map { Completion(habitID: "a", day: $0, level: .full) }
        let strong = StrengthEngine.values(habits: [h], completions: done, from: day("2026-10-01"), until: day("2026-10-11"), timeZone: utc)["a"]!
        let weak = StrengthEngine.values(habits: [h], completions: [], from: day("2026-10-01"), until: day("2026-10-11"), timeZone: utc)["a"]!
        #expect(strong > 5 && weak < -5)
    }

    @Test func todayDoesNotChangeTodaysPrice() {
        let today = day("2026-10-01")
        let v = StrengthEngine.values(habits: [h], completions: [done("a", "2026-10-01")], from: today, until: today, timeZone: utc)
        #expect(v["a"] == 0)
    }

    @Test func minimumIsHalfAStepAndValueIsClamped() {
        let one = StrengthEngine.values(habits: [h], completions: [done("a", "2026-10-01", .minimum)], from: day("2026-10-01"), until: day("2026-10-02"), timeZone: utc)
        #expect(abs(one["a"]! - 0.5) < 0.0001)
        let long = StrengthEngine.values(habits: [h], completions: [], from: day("2026-01-01"), until: day("2026-12-31"), timeZone: utc)
        #expect(long["a"]! >= StrengthRules.minValue)
        #expect(StrengthRules.tier(long["a"]!) == .wilted)
    }

    @Test func restDaysFreezeStrength() {
        let rest: Set<DayKey> = Set(days(5))
        let v = StrengthEngine.values(habits: [h], completions: [], from: day("2026-10-01"), until: day("2026-10-06"), restDays: rest, timeZone: utc)
        #expect(v["a"] == 0)
    }

    @Test func habitStreakSkipsRestAndUnscheduledDays() {
        let completions = [done("a", "2026-10-01"), done("a", "2026-10-02"), done("a", "2026-10-04")]
        let n = StrengthEngine.habitStreak(h, completions: completions, before: day("2026-10-05"), start: day("2026-10-01"),
                                           restDays: [day("2026-10-03")], timeZone: utc)
        #expect(n == 3)
    }
}

@Suite struct EnergyTests {
    let habits = [habit("a", .hard), habit("b", .easy)]

    @Test func missesDrainPerfectDaysRefill() {
        let start = day("2026-10-01")
        let missedOne = EnergyEngine.evaluate(habits: habits, completions: [done("a", "2026-10-01")], from: start, until: day("2026-10-02"), timeZone: utc)
        #expect(missedOne.value == 100 - EnergyRules.drain(.easy))
        let missedAll = EnergyEngine.evaluate(habits: habits, completions: [], from: start, until: day("2026-10-03"), timeZone: utc)
        #expect(missedAll.value == 100 - 2 * (12 + 6))
        #expect(missedAll.greyness > 0)
    }

    @Test func neverMissTwiceRefundsHalf() {
        let completions = [done("a", "2026-10-01"), done("a", "2026-10-02"), done("b", "2026-10-02")]
        let e = EnergyEngine.evaluate(habits: habits, completions: completions, from: day("2026-10-01"), until: day("2026-10-03"), timeZone: utc)
        // day 1: -6 (b missed). day 2: b recovered -> +3, perfect -> +25, capped at 100.
        #expect(e.value == 100)
        let noRecovery = EnergyEngine.evaluate(habits: [habit("b", .easy)], completions: [done("b", "2026-10-02")],
                                               from: day("2026-10-01"), until: day("2026-10-02"), timeZone: utc)
        #expect(noRecovery.value == 94)
    }

    @Test func energyNeverBelowZeroAndLevelUpRefills() {
        let drained = EnergyEngine.evaluate(habits: habits, completions: [], from: day("2026-10-01"), until: day("2026-10-20"), timeZone: utc)
        #expect(drained.value == 0)
        let refilled = EnergyEngine.evaluate(habits: habits, completions: [], from: day("2026-10-01"), until: day("2026-10-20"),
                                             levelUpDays: [day("2026-10-19")], timeZone: utc)
        #expect(refilled.value == 100)
    }

    @Test func levelUpDaysComeFromTheLedger() {
        let ledger = GritLedger([GritTransaction(day: day("2026-10-01"), amount: 0, reason: .habit, ref: "x", xp: 60),
                                 GritTransaction(day: day("2026-10-02"), amount: 0, reason: .habit, ref: "y", xp: 60)])
        #expect(EnergyEngine.levelUpDays(ledger) == [day("2026-10-02")]) // 120 XP crosses level 2 at 100
    }
}

@Suite struct DropAndStrikeTests {
    @Test func rollsAreDeterministic() {
        let d = day("2026-10-16")
        #expect(StableRoll.unit("x") == StableRoll.unit("x"))
        #expect(StrikeRules.isStrike(habitID: "a", day: d) == StrikeRules.isStrike(habitID: "a", day: d))
        let u = StableRoll.unit("strike|a|2026-10-16")
        #expect(u >= 0 && u < 1)
    }

    @Test func strikeRateIsAboutFourPercent() {
        let days = DayKey.range(day("2026-01-01"), through: day("2026-12-31"), timeZone: utc)
        let hits = days.flatMap { d in (0..<10).map { StrikeRules.isStrike(habitID: "h\($0)", day: d) } }.filter { $0 }.count
        let rate = Double(hits) / Double(days.count * 10)
        #expect(rate > 0.025 && rate < 0.055)
    }

    @Test func weakHabitsDropMoreOftenAndDropsRespectLevel() {
        #expect(DropRules.chance(strengthValue: -47) > DropRules.chance(strengthValue: 21))
        let days = DayKey.range(day("2026-01-01"), through: day("2026-12-31"), timeZone: utc)
        let drops = days.compactMap { DropRules.roll(habitID: "a", day: $0, strengthValue: -47, level: 1) }
        #expect(!drops.isEmpty)
        #expect(drops.allSatisfy { (Catalog.item($0.itemID)?.minLevel ?? 99) <= 1 }) // no level-locked plants, no koi at level 1
    }

    @Test func restDaysAreCappedPerMonth() {
        let used: Set<DayKey> = [day("2026-10-01"), day("2026-10-05"), day("2026-10-09")]
        #expect(!RestRules.canRest(on: day("2026-10-20"), restDays: used))
        #expect(RestRules.canRest(on: day("2026-11-01"), restDays: used))
        #expect(RestRules.canRest(on: day("2026-10-05"), restDays: used)) // already a rest day
    }

    @Test func restDayPausesTheStreak() {
        let habits = [habit("a")]
        let completions = [done("a", "2026-10-01"), done("a", "2026-10-03")]
        let s = StreakEngine(timeZone: utc).evaluate(from: day("2026-10-01"), through: day("2026-10-03"), habits: habits,
                                                     completions: completions, restDays: [day("2026-10-02")])
        #expect(s.current == 2)
        #expect(s.outcomes[day("2026-10-02")] == .rest)
    }

    @Test func treatsClampPrices() {
        #expect(Treat(name: "  Cheat meal ", price: 0).price == 1)
        #expect(Treat(name: "  Cheat meal ", price: 150).name == "Cheat meal")
    }
}

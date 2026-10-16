import Foundation
import Testing
@testable import MasteryCore

@Suite struct SleepTests {
    @Test func hoursInBedCrossMidnight() {
        let entry = SleepEntry(wakeDay: day("2026-10-16"), bedtime: ClockTime(hour: 23, minute: 0), wakeTime: ClockTime(hour: 6, minute: 30))
        #expect(entry.hoursInBed == 7.5)
        #expect(entry.effectiveHours == 7.5)
    }

    @Test func manualHoursOverrideTimeInBed() {
        let entry = SleepEntry(wakeDay: day("2026-10-16"), bedtime: ClockTime(hour: 23, minute: 0),
                               wakeTime: ClockTime(hour: 7, minute: 0), hoursSlept: 6.5)
        #expect(entry.effectiveHours == 6.5)
    }

    @Test func onTargetNeedsBedtimeWithinToleranceAndEnoughSleep() {
        let target = SleepTarget(bedtime: ClockTime(hour: 23, minute: 45), hours: 7.5, toleranceMinutes: 30)
        // 00:10 is 25 min after 23:45 across midnight.
        let good = SleepEntry(wakeDay: day("2026-10-16"), bedtime: ClockTime(hour: 0, minute: 10), wakeTime: ClockTime(hour: 7, minute: 45))
        let late = SleepEntry(wakeDay: day("2026-10-16"), bedtime: ClockTime(hour: 1, minute: 0), wakeTime: ClockTime(hour: 9, minute: 0))
        let short = SleepEntry(wakeDay: day("2026-10-16"), bedtime: ClockTime(hour: 23, minute: 45), wakeTime: ClockTime(hour: 5, minute: 0))
        #expect(target.isOnTarget(good))
        #expect(!target.isOnTarget(late))
        #expect(!target.isOnTarget(short))
        #expect(MasteryEngine.sleepLevel(short, target: target) == .minimum)
    }

    @Test func statsSpreadTreatsMidnightAsContinuous() throws {
        let entries = [
            SleepEntry(wakeDay: day("2026-10-15"), bedtime: ClockTime(hour: 23, minute: 30), wakeTime: ClockTime(hour: 7, minute: 0)),
            SleepEntry(wakeDay: day("2026-10-16"), bedtime: ClockTime(hour: 0, minute: 30), wakeTime: ClockTime(hour: 8, minute: 0))
        ]
        let stats = try #require(SleepStats.compute(entries, target: SleepTarget()))
        #expect(stats.bedtimeSpreadMinutes == 30)
        #expect(stats.averageHours == 7.5)
        #expect(stats.debtHours == 0)
        #expect(SleepStats.compute([], target: SleepTarget()) == nil)
    }

    @Test func qualityIsClamped() {
        #expect(SleepEntry(wakeDay: day("2026-10-16"), bedtime: ClockTime(minutes: 0), wakeTime: ClockTime(minutes: 60), quality: 9).quality == 5)
    }
}

@Suite struct GateTests {
    let config = GateConfig()

    func decide(_ h: Int, _ m: Int, morningDone: Bool, lockedIn: Bool = false, unblock: Bool = false) -> ShieldDecision {
        GatePolicy.decide(config: config, now: ClockTime(hour: h, minute: m), morningDone: morningDone,
                          lockedInActive: lockedIn, unblockActive: unblock)
    }

    @Test func morningGateLocksUntilRoutineDone() {
        #expect(decide(7, 0, morningDone: false).reason == .morningGate)
        #expect(decide(7, 0, morningDone: true).reason == .noSocialSchedule)
    }

    @Test func allowedWindowOpensApps() {
        #expect(!decide(19, 10, morningDone: true).shield)
        #expect(decide(19, 30, morningDone: true).shield)
    }

    @Test func windDownLocksEvenIfMorningDone() {
        #expect(decide(22, 0, morningDone: true).reason == .windDown)
    }

    @Test func lockedInBeatsPaidUnblock() {
        #expect(decide(19, 10, morningDone: true, lockedIn: true, unblock: true).reason == .lockedInFocus)
        #expect(!decide(8, 0, morningDone: false, unblock: true).shield)
    }

    @Test func windowCrossingMidnight() {
        let window = TimeWindow(start: ClockTime(hour: 23, minute: 0), end: ClockTime(hour: 1, minute: 0))
        #expect(window.contains(ClockTime(hour: 0, minute: 30)))
        #expect(!window.contains(ClockTime(hour: 2, minute: 0)))
    }
}

@Suite struct WorldTests {
    @Test func buyPlaceAndPickUp() throws {
        let world = try WorldState().buying("bamboo", level: 1).placing("bamboo", x: 0, y: 0)
        #expect(world.placement(atX: 0, y: 0)?.itemID == "bamboo")
        #expect(world.inventory["bamboo"] == 0)
        let back = try world.removing(atX: 0, y: 0)
        #expect(back.inventory["bamboo"] == 1)
    }

    @Test func placementRules() throws {
        let world = try WorldState().buying("bamboo", level: 1)
        #expect(throws: WorldError.occupied) { try world.placing("bamboo", x: 1, y: 1) }
        #expect(throws: WorldError.outOfBounds) { try world.placing("bamboo", x: 3, y: 0) }
        #expect(throws: WorldError.notOwned) { try world.placing("pine", x: 0, y: 0) }
        #expect(throws: WorldError.levelTooLow(required: 20)) { try world.buying("dojo", level: 5) }
    }

    @Test func landExpandsToNineThenStops() throws {
        let max = try WorldState().expanded().expanded().expanded()
        #expect(max.landSize == 9)
        #expect(throws: WorldError.maxLand) { try max.expanded() }
    }
}

@Suite struct ReviewFixTests {
    @Test func impossibleDatesAreRejected() {
        #expect(DayKey("2026-02-31") == nil)
        #expect(DayKey("2026-02-28") != nil)
        #expect(DayKey("2028-02-29") != nil)
    }

    @Test func springForwardNightIsAnHourShorter() throws {
        let ny = try #require(TimeZone(identifier: "America/New_York"))
        // US DST starts 2027-03-14 at 02:00.
        let entry = SleepEntry(wakeDay: day("2027-03-14"), bedtime: ClockTime(hour: 23, minute: 0), wakeTime: ClockTime(hour: 7, minute: 0))
        #expect(entry.hoursInBed(timeZone: ny) == 7)
        #expect(entry.hoursInBed(timeZone: utc) == 8)
    }

    @Test func archivingKeepsPastDaysRequired() {
        let a = habit("a")
        let b = habit("b").active(from: nil, until: day("2026-10-03"))
        let completions = [done("a", "2026-10-01"), done("a", "2026-10-02"), done("a", "2026-10-03"), done("a", "2026-10-04")]
        let state = StreakEngine(timeZone: utc).evaluate(from: day("2026-10-01"), through: day("2026-10-04"),
                                                         habits: [a, b], completions: completions)
        // b was required (and missed) on 01 and 02; after archiving on 03 only a counts.
        #expect(state.outcomes[day("2026-10-01")] == .missed)
        #expect(state.outcomes[day("2026-10-03")] == .perfect)
        #expect(state.current == 2)
    }

    @Test func newHabitIsNotRequiredBeforeItExisted() {
        let a = habit("a")
        let b = habit("b").active(from: day("2026-10-03"), until: nil)
        let completions = [done("a", "2026-10-01"), done("a", "2026-10-02")]
        let state = StreakEngine(timeZone: utc).evaluate(from: day("2026-10-01"), through: day("2026-10-02"),
                                                         habits: [a, b], completions: completions)
        #expect(state.current == 2)
    }

    @Test func undoAfterSpendingGoesNegativeInsteadOfFarming() throws {
        var s = MasteryState(habits: [habit("a", .hard)], completions: [], ledger: GritLedger(), startDay: day("2026-10-01"), timeZone: utc)
        s = MasteryEngine.log(.full, habitID: "a", day: day("2026-10-01"), in: s).state
        let spent = try s.ledger.spending(15, day: day("2026-10-01"), reason: .purchase, ref: "bamboo")
        s = MasteryState(habits: s.habits, completions: s.completions, ledger: spent, startDay: s.startDay, timeZone: utc)
        s = MasteryEngine.clear(habitID: "a", day: day("2026-10-01"), in: s).state
        #expect(s.ledger.balance == -15)
        s = MasteryEngine.log(.full, habitID: "a", day: day("2026-10-01"), in: s).state
        #expect(s.ledger.balance == 0)
    }

    @Test func snapshotResolvesOverlapsInPriorityOrder() throws {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = utc
        let at1910 = try #require(cal.date(from: DateComponents(year: 2026, month: 10, day: 16, hour: 19, minute: 10)))
        let base = GateSnapshot(config: GateConfig(), active: true, morningDoneDay: day("2026-10-16"), unblockUntil: nil, lockedInUntil: nil)
        #expect(!base.decide(now: at1910, timeZone: utc).shield) // inside the social window
        let locked = GateSnapshot(config: GateConfig(), active: true, morningDoneDay: day("2026-10-16"),
                                  unblockUntil: nil, lockedInUntil: at1910.addingTimeInterval(600))
        #expect(locked.decide(now: at1910, timeZone: utc).reason == .lockedInFocus) // window can't open locked-in
        let yesterday = GateSnapshot(config: GateConfig(), active: true, morningDoneDay: day("2026-10-15"), unblockUntil: nil, lockedInUntil: nil)
        #expect(yesterday.decide(now: at1910, timeZone: utc).reason == .morningGate) // window needs today's morning
        let off = GateSnapshot(config: GateConfig(), active: false, morningDoneDay: nil, unblockUntil: nil, lockedInUntil: nil)
        #expect(!off.decide(now: at1910, timeZone: utc).shield)
    }
}

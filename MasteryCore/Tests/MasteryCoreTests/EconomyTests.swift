import Testing
@testable import MasteryCore

@Suite struct EconomyTests {
    @Test func fullHabitPaysBaseGritAndTenXP() {
        #expect(RewardRules.habitReward(difficulty: .hard, level: .full) == Reward(grit: 15, xp: 10))
    }

    @Test func minimumPaysHalfRoundedUp() {
        #expect(RewardRules.habitReward(difficulty: .easy, level: .minimum).grit == 3)
        #expect(RewardRules.habitReward(difficulty: .medium, level: .minimum).grit == 5)
    }

    @Test func slippedAndNotDonePayNothing() {
        #expect(RewardRules.habitReward(difficulty: .hard, level: .slipped, habitStreakDays: 30, strike: true) == .zero)
        #expect(RewardRules.habitReward(difficulty: .hard, level: .notDone, habitStreakDays: 30) == .zero)
    }

    @Test func habitStreakBonusIsOnePercentPerDayCappedAtThirty() {
        #expect(RewardRules.habitStreakBonus(days: 10) == 0.10)
        #expect(RewardRules.habitStreakBonus(days: 100) == 0.30)
        #expect(RewardRules.habitStreakBonus(days: -3) == 0)
        #expect(RewardRules.habitReward(difficulty: .medium, level: .full, habitStreakDays: 30).grit == 13)
    }

    @Test func weakHabitsPayMoreAndStrikesDouble() {
        let neglected = RewardRules.habitReward(difficulty: .medium, level: .full, strengthValue: -47).grit
        let mastered = RewardRules.habitReward(difficulty: .medium, level: .full, strengthValue: 21).grit
        #expect(neglected == 30) // capped at 3x
        #expect(mastered == 6)   // 0.58x
        #expect(RewardRules.habitReward(difficulty: .medium, level: .full, strike: true).grit == 20)
    }

    @Test func focusPaysOneGritPerFiveMinutesAndOneXPPerMinute() {
        #expect(RewardRules.focusReward(minutes: 25, lockedIn: false, stoppedEarly: false) == Reward(grit: 5, xp: 25))
    }

    @Test func lockedInPaysOneAndAHalfTimes() {
        #expect(RewardRules.focusReward(minutes: 50, lockedIn: true, stoppedEarly: false).grit == 15)
    }

    @Test func lockedInEarlyStopIsPenalised() {
        #expect(RewardRules.focusReward(minutes: 10, lockedIn: true, stoppedEarly: true).grit == -8)
    }

    @Test func levelCurve() {
        #expect(Leveling.progress(totalXP: 0).level == 1)
        #expect(Leveling.progress(totalXP: 99).level == 1)
        #expect(Leveling.progress(totalXP: 100).level == 2)
        #expect(Leveling.progress(totalXP: 300).level == 3)
        let p = Leveling.progress(totalXP: 150)
        #expect(p.xpIntoLevel == 50 && p.xpForNextLevel == 200)
    }

    @Test func belts() {
        #expect(Belt.forLevel(1) == .white)
        #expect(Belt.forLevel(5) == .yellow)
        #expect(Belt.forLevel(29) == .blue)
        #expect(Belt.forLevel(50) == .black)
    }

    @Test func ledgerRefusesOverspend() throws {
        let ledger = GritLedger([GritTransaction(day: day("2026-10-16"), amount: 30, reason: .habit, ref: "x")])
        #expect(throws: LedgerError.insufficientGrit(needed: 50, balance: 30)) {
            try ledger.spending(50, day: day("2026-10-16"), reason: .purchase, ref: "pond")
        }
        let after = try ledger.spending(30, day: day("2026-10-16"), reason: .purchase, ref: "bamboo")
        #expect(after.balance == 0)
        #expect(ledger.balance == 30) // original untouched
    }

    @Test func focusPenaltyNeverGoesBelowZero() {
        let ledger = GritLedger([GritTransaction(day: day("2026-10-16"), amount: 4, reason: .habit, ref: "x")])
        let session = FocusSession(day: day("2026-10-16"), plannedMinutes: 25, focusedMinutes: 3, lockedIn: true)
        let result = FocusEngine.record(session, ledger: ledger)
        #expect(result.ledger.balance == 0)
        #expect(result.reward.xp == 3)
    }

    @Test func timerHabitLevelFromMinutes() {
        let meditation = habit("meditation", kind: .timer, target: 10, min: 2)
        #expect(FocusEngine.habitLevel(minutes: 1, habit: meditation) == nil)
        #expect(FocusEngine.habitLevel(minutes: 2, habit: meditation) == .minimum)
        #expect(FocusEngine.habitLevel(minutes: 10, habit: meditation) == .full)
    }
}

import Testing
@testable import MasteryCore

@Suite struct ReminderTests {
    let today = day("2026-10-16")
    let habits = [habit("meditation"), habit("workout"), habit("no-nicotine", kind: .avoid)]

    func plan(now: ClockTime, completions: [Completion] = [], streak: Int = 5,
              plans: [String: HabitPlan] = ["meditation": HabitPlan(time: ClockTime(hour: 7, minute: 0), place: "the bedroom"),
                                            "workout": HabitPlan(time: ClockTime(hour: 18, minute: 0), place: nil)]) -> [Reminder] {
        ReminderPlanner.plan(day: today, now: now, habits: habits, plans: plans, index: CompletionIndex(completions),
                             gate: GateConfig(), streakDays: streak, timeZone: utc)
    }

    @Test func cueReadsAsAWhenWherePlan() {
        let cue = plan(now: ClockTime(hour: 6, minute: 0)).first { $0.id == "cue.meditation" }
        #expect(cue?.body.hasPrefix("At 07:00 in the bedroom") == true)
    }

    @Test func noCueForPastTimesOrDoneHabits() {
        let ids = plan(now: ClockTime(hour: 12, minute: 0), completions: [done("workout", "2026-10-16")]).map(\.id)
        #expect(!ids.contains("cue.meditation")) // 07:00 already passed
        #expect(!ids.contains("cue.workout"))    // done
    }

    @Test func windDownWarningFifteenMinutesBeforeLock() {
        let warn = plan(now: ClockTime(hour: 12, minute: 0)).first { $0.kind == .windDownWarning }
        #expect(warn?.time == ClockTime(hour: 21, minute: 15))
    }

    @Test func streakAtRiskOnlyWhenSomethingOpenAndStreakExists() {
        #expect(plan(now: ClockTime(hour: 12, minute: 0)).contains { $0.kind == .streakAtRisk })
        let allDone = habits.map { done($0.id, "2026-10-16") }
        #expect(!plan(now: ClockTime(hour: 12, minute: 0), completions: allDone).contains { $0.kind == .streakAtRisk })
        #expect(!plan(now: ClockTime(hour: 12, minute: 0), streak: 0).contains { $0.kind == .streakAtRisk })
    }

    @Test func remindersAreSortedAndPlacesTrimmed() {
        let times = plan(now: ClockTime(hour: 6, minute: 0)).map(\.time)
        #expect(times == times.sorted())
        #expect(HabitPlan(time: nil, place: "   ").cue == nil)
        #expect(HabitPlan(time: nil, place: " gym ").cue == "In gym")
    }
}

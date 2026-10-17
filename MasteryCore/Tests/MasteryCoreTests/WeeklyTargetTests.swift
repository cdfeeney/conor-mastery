import Testing
@testable import MasteryCore

/// "3 times a week" habits: Monday-start weeks, progress, coach rates and reminders.
@Suite struct WeeklyTargetTests {
    private let gym = habit("gym", schedule: .timesPerWeek(3))
    private let wednesday = day("2026-10-21")

    @Test func weeksStartOnMonday() {
        #expect(wednesday.weekStart(timeZone: utc) == day("2026-10-19"))
        #expect(day("2026-10-25").weekStart(timeZone: utc) == day("2026-10-19"))   // Sunday
        #expect(day("2026-10-26").weekStart(timeZone: utc) == day("2026-10-26"))   // Monday
    }

    @Test func progressCountsThisWeekOnly() {
        let index = CompletionIndex([done("gym", "2026-10-18"), done("gym", "2026-10-19"), done("gym", "2026-10-21", .minimum)])
        let progress = WeeklyTargets.progress(gym, index: index, on: wednesday, timeZone: utc)
        #expect(progress == WeeklyProgress(done: 2, target: 3, daysLeft: 5, isDoneToday: true))
        #expect(progress?.isMet == false)
        #expect(WeeklyTargets.progress(habit("daily"), index: index, on: wednesday, timeZone: utc) == nil)
    }

    @Test func atRiskWhenTheDaysLeftOnlyJustCoverIt() {
        let sunday = day("2026-10-25")
        let index = CompletionIndex([done("gym", "2026-10-20"), done("gym", "2026-10-22")])
        #expect(WeeklyTargets.progress(gym, index: index, on: sunday, timeZone: utc)?.isAtRisk == true)
        #expect(WeeklyTargets.progress(gym, index: index, on: wednesday, timeZone: utc)?.isAtRisk == false)
    }

    @Test func dailyTicksBeforeASwitchDontFillTheWeek() {
        let switched = habit("gym", schedule: .changed(before: .daily, after: .timesPerWeek(3), from: day("2026-10-22")))
        let index = CompletionIndex(["2026-10-19", "2026-10-20", "2026-10-21"].map { done("gym", $0) })
        let progress = WeeklyTargets.progress(switched, index: index, on: day("2026-10-22"), timeZone: utc)
        #expect(progress?.done == 0)
        #expect(progress?.target == 3)          // Thu-Sun: 4 eligible days
    }

    @Test func habitAddedOnSundayGetsACappedTarget() {
        let late = gym.active(from: day("2026-10-25"), until: nil)
        #expect(WeeklyTargets.progress(late, index: CompletionIndex([]), on: day("2026-10-25"), timeZone: utc)?.target == 1)
    }

    @Test func doneTodayStillAtRiskWhenOnlyTomorrowRemains() {
        let saturday = day("2026-10-24")
        let index = CompletionIndex(["2026-10-20", "2026-10-24"].map { done("gym", $0) })
        #expect(WeeklyTargets.progress(gym, index: index, on: saturday, timeZone: utc)?.isAtRisk == true)
    }

    @Test func mixedScheduleRatesKeepBothParts() {
        // Weekly (2/week) for 10-19..25, then daily from 10-26.
        let mixed = habit("gym", schedule: .changed(before: .timesPerWeek(2), after: .daily, from: day("2026-10-26")))
        let completions = ["2026-10-20", "2026-10-26", "2026-10-27"].map { done("gym", $0) }
        let row = ConsistencyReport.compute(habits: [mixed], completions: completions, today: day("2026-10-31"), timeZone: utc).first
        #expect(row?.required == 2 + 5)         // one weekly week + daily 10-26..30
        #expect(row?.done == 1 + 2)
    }

    @Test func scheduleEditedToWeeklyIsRecognised() {
        let edited = habit("gym", schedule: .changed(before: .daily, after: .timesPerWeek(2), from: day("2026-10-01")))
        #expect(WeeklyTargets.progress(edited, index: CompletionIndex([]), on: wednesday, timeZone: utc)?.target == 2)
    }

    @Test func coachRatesUseFullWeeksCappedAtTheTarget() {
        // Window is 10-17..10-30 (today Sat 10-31): only the Monday week 10-19..25 lies fully inside it.
        let completions = ["2026-10-13", "2026-10-14", "2026-10-15", "2026-10-16", "2026-10-20"].map { done("gym", $0) }
        let report = ConsistencyReport.compute(habits: [gym], completions: completions, today: day("2026-10-31"), timeZone: utc)
        #expect(report.first?.required == 3)
        #expect(report.first?.done == 1)
    }

    @Test func remindersCueOpenWeeklyHabitsButNotTheStreakCheck() {
        let plans = ["gym": HabitPlan(time: ClockTime(hour: 18, minute: 0), place: "Gym")]
        let reminders = ReminderPlanner.plan(day: wednesday, now: ClockTime(hour: 9, minute: 0), habits: [gym], plans: plans,
                                             index: CompletionIndex([]), gate: GateConfig(), streakDays: 5, timeZone: utc)
        #expect(reminders.contains { $0.id == "cue.gym" })
        #expect(!reminders.contains { $0.kind == .streakAtRisk })
        let met = CompletionIndex(["2026-10-19", "2026-10-20", "2026-10-21"].map { done("gym", $0) })
        let none = ReminderPlanner.plan(day: wednesday, now: ClockTime(hour: 9, minute: 0), habits: [gym], plans: plans,
                                        index: met, gate: GateConfig(), streakDays: 5, timeZone: utc)
        #expect(!none.contains { $0.id == "cue.gym" })
    }
}

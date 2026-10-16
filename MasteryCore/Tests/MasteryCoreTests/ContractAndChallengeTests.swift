import Foundation
import Testing
@testable import MasteryCore

@Suite struct ContractTests {
    let planJSON = """
    {"format":"conor-mastery-plan","version":1,"generated_at":"2026-10-16T09:00:00-04:00",
     "weekly_focus":"Bedtime","future_field":true,
     "habits":[{"id":"meditation","title":"Meditation","kind":"timer","difficulty":"medium","group":"morning",
       "schedule":"weekdays:2,3,4,5,6","identity":"I am calm","why":"because","full":"10 min","min":"2 min",
       "target_minutes":10,"min_minutes":2,"citations":[{"source":"yt:abc","locator":"12:34"}],"challenges":["Sit 12 min"]}]}
    """

    @Test func decodesPlanAndIgnoresUnknownFields() throws {
        let plan = try JSONDecoder().decode(MasteryPlan.self, from: Data(planJSON.utf8)).validated()
        #expect(plan.notes.isEmpty)
        let def = plan.habits[0].definition(anchor: day("2026-10-01"))
        #expect(def.schedule == .weekdays([2, 3, 4, 5, 6]))
        #expect(def.targetMinutes == 10)
        #expect(def.citations.first?.locator == "12:34")
    }

    @Test func rejectsWrongFormat() throws {
        let bad = planJSON.replacingOccurrences(of: "conor-mastery-plan", with: "coach-kb-week")
        let plan = try JSONDecoder().decode(MasteryPlan.self, from: Data(bad.utf8))
        #expect(throws: ContractError.wrongFormat("coach-kb-week")) { try plan.validated() }
    }

    @Test func scheduleParsingIsLenient() {
        let anchor = day("2026-10-01")
        #expect(PlanHabit.parseSchedule("every:2", anchor: anchor) == .everyNDays(n: 2, anchor: anchor))
        #expect(PlanHabit.parseSchedule("per-week:9", anchor: anchor) == .timesPerWeek(7))
        #expect(PlanHabit.parseSchedule("garbage", anchor: anchor) == .daily)
        #expect(PlanHabit.parseSchedule("weekdays:0,8", anchor: anchor) == .daily)
    }

    @Test func dailyLogOmitsEmptyDaysAndUsesSnakeCase() throws {
        let sleep = SleepEntry(wakeDay: day("2026-10-16"), bedtime: ClockTime(hour: 22, minute: 30), wakeTime: ClockTime(hour: 6, minute: 30))
        let log = DailyLogBuilder.build(
            days: [day("2026-10-15"), day("2026-10-16")],
            completions: [done("meditation", "2026-10-16", .minimum), done("meditation", "2026-10-16")],
            sleep: [sleep], target: SleepTarget(), focusMinutes: [day("2026-10-16"): 25],
            outcomes: [:], reflections: [:], generatedAt: "2026-10-16T21:00:00-04:00")
        #expect(log.days.count == 1)
        #expect(log.days[0].habits.count == 1)
        #expect(log.days[0].habits[0].status == .full) // last write wins
        let json = String(decoding: try JSONEncoder().encode(log), as: UTF8.self)
        #expect(json.contains("\"focus_minutes\":25"))
        #expect(json.contains("\"hours_in_bed\":8"))
        #expect(json.contains("\"bedtime\":\"22:30\""))
    }

    @Test func conorHealthSessionLogCompletesWorkout() throws {
        let raw = #"{"format":"coach-kb-session-log","version":1,"session_id":"x","date":"2026-10-05","duration_min":48,"exercises":[]}"#
        let log = try JSONDecoder().decode(ConorHealthSessionLog.self, from: Data(raw.utf8))
        let completion = try #require(log.workoutCompletion())
        #expect(completion.day == day("2026-10-05") && completion.source == .conorhealth && completion.minutes == 48)
    }

    @Test func badDateIsRejected() {
        #expect(DayKey("2026-13-01") == nil)
        #expect(DayKey("2026-1-01") == nil)
    }
}

@Suite struct ChallengeTests {
    @Test func picksWeakestHabitWithChallenges() throws {
        let habits = [habit("strong", challenges: ["s1"]), habit("weak", challenges: ["w1", "w2"])]
        let today = day("2026-10-16")
        let history = DayKey.range(day("2026-10-02"), through: day("2026-10-15"), timeZone: utc).map { done("strong", $0.rawValue) }
        let challenge = try #require(ChallengePicker.pick(habits: habits, completions: history, today: today, timeZone: utc))
        #expect(challenge.habitID == "weak")
        #expect(challenge.reward == 20)
        #expect(["w1", "w2"].contains(challenge.text))
    }

    @Test func dayOneStillGetsAChallenge() {
        let habits = [habit("a", challenges: ["go"])]
        #expect(ChallengePicker.pick(habits: habits, completions: [], today: day("2026-10-01"), timeZone: utc)?.habitID == "a")
    }

    @Test func noChallengesMeansNil() {
        #expect(ChallengePicker.pick(habits: [habit("a")], completions: [], today: day("2026-10-01"), timeZone: utc) == nil)
    }
}

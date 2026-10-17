import Testing
@testable import MasteryCore

@Suite struct HabitEditingTests {
    private let coach = PlanHabit(id: "meditation", title: "Meditation", kind: .timer, difficulty: .medium, group: .morning,
                                  schedule: "daily", identity: "I am calm.", why: "Why.", full: "10 minutes", min: "2 minutes",
                                  targetMinutes: 10, minMinutes: 2)

    @Test func scheduleChoiceRoundTrips() {
        let cases: [ScheduleChoice] = [.daily, .weekdays([2, 4, 6]), .perWeek(3)]
        for choice in cases { #expect(ScheduleChoice(raw: choice.raw) == choice) }
        #expect(ScheduleChoice.weekdays([6, 2, 4]).raw == "weekdays:2,4,6")
        #expect(ScheduleChoice(raw: "every:2") == .daily)   // not offered in the editor: shown as daily
        #expect(ScheduleChoice(raw: "weekdays:") == .daily)
    }

    @Test func editKeepsIdentityKindAndSourcesButTakesYourText() {
        let edited = coach.edited(title: "  Morning sit ", full: "15 minutes", min: "", group: .night,
                                  difficulty: .hard, schedule: .perWeek(5), steps: nil, targetMinutes: 15, minMinutes: 3)
        #expect(edited.id == "meditation")
        #expect(edited.kind == .timer)
        #expect(edited.title == "Morning sit")
        #expect(edited.min == nil)                          // blank Min means no bad-day version
        #expect(edited.schedule == "per-week:5")
        #expect(edited.targetMinutes == 15)
        #expect(edited.identity == coach.identity)
    }

    @Test func blankTitleOrFullIsRejected() {
        #expect(HabitEditor.problem(title: " ", full: "x") != nil)
        #expect(HabitEditor.problem(title: "Read", full: "") != nil)
        #expect(HabitEditor.problem(title: "Read", full: "10 pages") == nil)
    }

    @Test func yourEditsWinAndCustomHabitsAppendInOrder() {
        let mine = HabitEditor.newCustom(title: "Read", kind: .build, group: .night, full: "10 pages", existingIDs: ["meditation"])
        let edit = coach.edited(title: "Sit", full: "5 minutes", min: nil, group: .morning, difficulty: .easy,
                                schedule: .daily, steps: nil, targetMinutes: 5, minMinutes: 1)
        let habits = HabitEditor.effective(plan: [coach], edits: ["meditation": edit], custom: [mine])
        #expect(habits.map(\.title) == ["Sit", "Read"])
    }

    @Test func customIDsAreUniqueAndPrefixed() {
        let first = HabitEditor.newCustom(title: "Read!", kind: .build, group: .day, full: "x", existingIDs: [])
        let second = HabitEditor.newCustom(title: "Read", kind: .build, group: .day, full: "x", existingIDs: [first.id])
        #expect(first.id == "my-read")
        #expect(second.id == "my-read-2")
    }

    @Test func scheduleEditNeverRewritesPastDays() {
        let monday = DayKey("2026-10-19")!          // weekday 2
        let saturday = DayKey("2026-10-17")!        // weekday 7, before the edit
        let changes = HabitEditor.recording([], current: "daily", new: "weekdays:2,3,4,5,6", today: monday)
        let schedule = HabitEditor.schedule(current: "weekdays:2,3,4,5,6", changes: changes, anchor: saturday)
        #expect(schedule.isRequired(on: saturday))                      // was daily then
        #expect(!schedule.isRequired(on: DayKey("2026-10-24")!))        // Saturday after the edit
        #expect(schedule.isRequired(on: DayKey("2026-10-20")!))
    }

    @Test func sameDayEditsCollapseAndUndoRemovesTheChange() {
        let day = DayKey("2026-10-19")!
        let once = HabitEditor.recording([], current: "daily", new: "weekdays:2", today: day)
        let twice = HabitEditor.recording(once, current: "weekdays:2", new: "weekdays:3", today: day)
        #expect(twice == [ScheduleChange(from: day, before: "daily", after: "weekdays:3")])
        #expect(HabitEditor.recording(twice, current: "weekdays:3", new: "daily", today: day).isEmpty)
        #expect(HabitEditor.recording([], current: "daily", new: "daily", today: day).isEmpty)
    }

    @Test func coachUpdatesStillArriveUnderAnEdit() {
        let edit = coach.edited(title: "Sit", full: "5 minutes", min: nil, group: .night, difficulty: .easy,
                                schedule: .daily, steps: nil, targetMinutes: 5, minMinutes: 1)
        let newer = PlanHabit(id: "meditation", title: "Meditation", kind: .timer, difficulty: .medium, group: .morning,
                              schedule: "daily", identity: "New identity", why: "New why", full: "10 minutes",
                              challenges: ["New challenge"])
        let merged = HabitEditor.effective(plan: [newer], edits: ["meditation": edit], custom: [])[0]
        #expect(merged.title == "Sit")
        #expect(merged.group == .night)
        #expect(merged.identity == "New identity")
        #expect(merged.challenges == ["New challenge"])
    }

    @Test func clashingCustomIDNeverDuplicates() {
        let clash = PlanHabit(id: "meditation", title: "Mine", kind: .build, difficulty: .easy, group: .day,
                              schedule: "daily", identity: "", why: "", full: "x")
        let habits = HabitEditor.effective(plan: [coach], edits: [:], custom: [clash, clash])
        #expect(habits.map(\.id) == ["meditation"])
    }

    @Test func checklistStepsDropBlanks() {
        let edited = coach.edited(title: "T", full: "F", min: nil, group: .morning, difficulty: .easy, schedule: .daily,
                                  steps: ["Water", "  ", "Sun"], targetMinutes: nil, minMinutes: nil)
        #expect(edited.steps == ["Water", "Sun"])
    }
}

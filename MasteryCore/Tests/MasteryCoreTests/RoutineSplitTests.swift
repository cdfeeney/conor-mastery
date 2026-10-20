import Testing
@testable import MasteryCore

/// Owner 10-20: each routine step is its own habit, so missing one step is one miss, not the whole routine.
@Suite struct RoutineSplitTests {
    let today = day("2026-10-20")
    let routine = PlanHabit(id: "night-routine", title: "Night routine", kind: .checklist, difficulty: .medium,
                            group: .night, schedule: "daily", identity: "I end my day on purpose.", why: "Sleep.",
                            full: "All steps", min: "Lights dim", steps: ["Lights dim", "Phone outside the bedroom"],
                            challenges: ["Charge it in the kitchen"])

    @Test func routineBecomesOneHabitPerStep() {
        let defs = routine.definitions(anchor: today)
        #expect(defs.map(\.id) == ["night-routine.lights-dim", "night-routine.phone-outside-the-bedroom"])
        #expect(defs.map(\.title) == ["Lights dim", "Phone outside the bedroom"])
        #expect(defs.allSatisfy { $0.routine == "night-routine" && $0.kind == .build && $0.group == .night })
        #expect(defs.allSatisfy { $0.min == nil && $0.steps.isEmpty && $0.difficulty == .easy })
        // The routine's challenges arrive once, not once per step.
        #expect(defs.map(\.challenges) == [["Charge it in the kitchen"], []])
    }

    @Test func lookAlikeStepsGetUniqueIDs() {
        let twin = PlanHabit(id: "r", title: "R", kind: .checklist, difficulty: .medium, group: .day, schedule: "daily",
                             identity: "", why: "", full: "All", steps: ["Water", "Water!", "!!"])
        #expect(twin.definitions(anchor: today).map(\.id) == ["r.water", "r.water-2", "r.step"])
    }

    @Test func otherHabitsAndStepLessRoutinesStayWhole() {
        let walk = PlanHabit(id: "walk", title: "Walk", kind: .build, difficulty: .easy, group: .day,
                             schedule: "daily", identity: "", why: "", full: "Walk")
        #expect(walk.definitions(anchor: today).map(\.id) == ["walk"])
        let empty = PlanHabit(id: "my-routine", title: "Mine", kind: .checklist, difficulty: .medium, group: .day,
                              schedule: "daily", identity: "", why: "", full: "All", steps: [])
        #expect(empty.definitions(anchor: today).map(\.kind) == [.checklist])
    }

    @Test func archivingKeepsTheRoutineLink() {
        let step = routine.definitions(anchor: today)[0].active(from: today, until: day("2026-10-25"))
        #expect(step.routine == "night-routine")
    }

    @Test func missingOneStepMissesOnlyThatStep() {
        let defs = routine.definitions(anchor: today)
        let index = CompletionIndex([Completion(habitID: defs[0].id, day: today, level: .full)])
        #expect(index.isDone(defs[0].id, on: today))
        #expect(!index.isDone(defs[1].id, on: today))
    }

    @Test func routinePlanCuesOnceWhileAStepIsOpen() {
        let defs = routine.definitions(anchor: today)
        let plans = ["night-routine": HabitPlan(time: ClockTime(hour: 22, minute: 0), place: nil)]
        let done = CompletionIndex([Completion(habitID: defs[0].id, day: today, level: .full)])
        let cues = ReminderPlanner.plan(day: today, now: ClockTime(hour: 9, minute: 0), habits: defs, plans: plans,
                                        index: done, gate: GateConfig(enabled: false), streakDays: 0, timeZone: utc)
        #expect(cues.map(\.id) == ["cue.night-routine"])
        #expect(cues.first?.title == "Phone outside the bedroom")
    }

    @Test func morningGateOpensOnlyWhenEveryStepIsDone() {
        let morning = PlanHabit(id: "morning-routine", title: "Morning routine", kind: .checklist, difficulty: .medium,
                                group: .morning, schedule: "daily", identity: "", why: "", full: "All",
                                steps: ["Water", "Light"])
        let defs = morning.definitions(anchor: today)
        let one = CompletionIndex([Completion(habitID: defs[0].id, day: today, level: .full)])
        #expect(!GatePolicy.morningDone(habitID: "morning-routine", habits: defs, index: one, day: today, timeZone: utc))
        let both = CompletionIndex(defs.map { Completion(habitID: $0.id, day: today, level: .full) })
        #expect(GatePolicy.morningDone(habitID: "morning-routine", habits: defs, index: both, day: today, timeZone: utc))
        // Finished as one routine before the split: still unlocks that day.
        let whole = CompletionIndex([Completion(habitID: "morning-routine", day: today, level: .full)])
        #expect(GatePolicy.morningDone(habitID: "morning-routine", habits: defs, index: whole, day: today, timeZone: utc))
        // Nothing to complete (routine removed or off today): never locked.
        #expect(GatePolicy.morningDone(habitID: "morning-routine", habits: [], index: one, day: today, timeZone: utc))
    }
}

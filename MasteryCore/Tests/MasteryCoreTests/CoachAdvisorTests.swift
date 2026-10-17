import Testing
@testable import MasteryCore

/// The on-phone coach: picks the week's focus and writes notes from your last 14 days.
@Suite struct CoachAdvisorTests {
    private let today = day("2026-10-31")
    private let habits = [habit("workout"), habit("sleep"), habit("no-social-media", kind: .avoid)]

    /// Completions for `id` on the last `count` of the 14 days before today.
    private func doneDays(_ id: String, _ count: Int, level: CompletionLevel = .full) -> [Completion] {
        (1...14).prefix(count).map { Completion(habitID: id, day: today.adding(days: -$0, timeZone: utc), level: level) }
    }

    private func advise(_ completions: [Completion], sleep: [SleepEntry] = []) -> CoachAdvice? {
        CoachAdvisor.advise(habits: habits, completions: completions, sleep: sleep, today: today, timeZone: utc)
    }

    @Test func noHistoryMeansNoAdvice() {
        let fresh = CoachAdvisor.advise(habits: habits.map { $0.active(from: today, until: nil) }, completions: [],
                                        sleep: [], today: today, timeZone: utc)
        #expect(fresh == nil)
    }

    @Test func focusIsTheFirstShakyFoundationNotJustTheWeakest() {
        // Workout is weakest, but sleep comes first in the foundation order and is under 80%.
        let advice = advise(doneDays("workout", 2) + doneDays("sleep", 9) + doneDays("no-social-media", 14))
        #expect(advice?.focusHabitID == "sleep")
        #expect(advice?.focusLine.contains("9 of 14") == true)
        #expect(advice?.lessonOrder.first == "sleep")
    }

    @Test func strugglingHabitGetsTheMinNote() {
        let advice = advise(doneDays("workout", 3) + doneDays("sleep", 14) + doneDays("no-social-media", 14))
        #expect(advice?.notes.contains { $0.contains("workout") && $0.contains("a little workout") } == true)
    }

    @Test func everythingStrongMeansLevelUp() {
        let advice = advise(doneDays("workout", 14) + doneDays("sleep", 13) + doneDays("no-social-media", 14))
        #expect(advice?.focusHabitID == nil)
        #expect(advice?.notes.contains { $0.contains("raise the bar") } == true)
    }

    @Test func slipsOnAnAvoidHabitAreCalledOut() {
        let slips = (1...3).map { Completion(habitID: "no-social-media", day: today.adding(days: -$0, timeZone: utc), level: .slipped) }
        let advice = advise(doneDays("workout", 14) + doneDays("sleep", 14) + slips)
        #expect(advice?.notes.contains { $0.contains("slipped 3 times") } == true)
    }

    @Test func shortSleepAndDriftingBedtimesGetNotes() {
        let entries = (1...7).map { offset in
            SleepEntry(wakeDay: today.adding(days: -offset, timeZone: utc),
                       bedtime: ClockTime(hour: offset.isMultiple(of: 2) ? 23 : 1, minute: 0),
                       wakeTime: ClockTime(hour: 6, minute: 30))
        }
        let notes = advise(doneDays("workout", 14) + doneDays("sleep", 14) + doneDays("no-social-media", 14), sleep: entries)?.notes ?? []
        #expect(notes.contains { $0.contains("Averaging") })
        #expect(notes.contains { $0.contains("Bedtimes vary") })
    }

    @Test func duplicateHabitIDsDoNotCrash() {
        let doubled = habits + [habit("workout")]
        let advice = CoachAdvisor.advise(habits: doubled, completions: doneDays("workout", 2), sleep: [], today: today, timeZone: utc)
        #expect(advice != nil)
    }

    @Test func aCorrectedSlipNoLongerCounts() {
        let yesterday = today.adding(days: -1, timeZone: utc)
        let records = [Completion(habitID: "no-social-media", day: yesterday, level: .slipped),
                       Completion(habitID: "no-social-media", day: today, level: .slipped),
                       Completion(habitID: "no-social-media", day: yesterday, level: .full)]
        let notes = advise(doneDays("workout", 14) + doneDays("sleep", 14) + records)?.notes ?? []
        #expect(!notes.contains { $0.contains("slipped") })
    }

    @Test func atMostFourNotes() {
        let advice = advise(doneDays("workout", 1) + doneDays("sleep", 1) + doneDays("no-social-media", 1))
        #expect((advice?.notes.count ?? 0) <= CoachAdvisor.maxNotes)
    }
}

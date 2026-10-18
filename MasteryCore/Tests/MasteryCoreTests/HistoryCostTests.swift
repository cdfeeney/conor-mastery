import Foundation
import Testing
@testable import MasteryCore

/// Six months of history: the app recomputes these once per change (MasteryStore.refreshDerived), so one full
/// recompute must stay cheap. A generous bound on a debug build; it fails if a change makes the work quadratic.
@Suite struct HistoryCostTests {
    @Test func sixMonthsRecomputesQuickly() {
        let today = day("2026-10-31"), start = today.adding(days: -179, timeZone: utc)
        let ids = ["morning-routine", "sleep", "meditation", "workout", "reset-focus", "deep-breathing", "night-routine"]
        let habits = ids.map { habit($0) } + [habit("no-social-media", kind: .avoid), habit("no-nicotine", kind: .avoid)]
        let completions = (0..<180).flatMap { offset in
            habits.enumerated().compactMap { i, h -> Completion? in
                (offset + i) % 4 == 0 ? nil : Completion(habitID: h.id, day: start.adding(days: offset, timeZone: utc), level: .full)
            }
        }
        let state = MasteryState(habits: habits, completions: completions, ledger: GritLedger(), startDay: start, timeZone: utc)
        let clock = ContinuousClock()
        let took = clock.measure {
            _ = state.strength(on: today)
            _ = state.streak(through: today)
            _ = state.energy(on: today)
            _ = CompletionIndex(completions)
            for h in habits { _ = StrengthEngine.habitStreak(h, completions: completions, before: today, start: start, timeZone: utc) }
        }
        #expect(took < .milliseconds(500), "one recompute over 180 days took \(took)")
    }
}

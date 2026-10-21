import Foundation
import MasteryCore

/// Record <-> MasteryCore value conversions. Rows that no longer decode are skipped, never crash.
extension MasteryStore {
    nonisolated static func completion(_ r: CompletionRecord) -> Completion? {
        guard let day = DayKey(r.day), let level = CompletionLevel(rawValue: r.level),
              let source = CompletionSource(rawValue: r.source) else { return nil }
        return Completion(habitID: r.habitID, day: day, level: level, source: source,
                          minutes: r.minutes, stepsDone: r.stepsDone)
    }

    nonisolated static func record(_ c: Completion) -> CompletionRecord {
        CompletionRecord(habitID: c.habitID, day: c.day.rawValue, level: c.level.rawValue,
                         source: c.source.rawValue, minutes: c.minutes, stepsDone: c.stepsDone)
    }

    nonisolated static func transaction(_ r: LedgerRecord) -> GritTransaction? {
        guard let day = DayKey(r.day), let reason = GritReason(rawValue: r.reason) else { return nil }
        return GritTransaction(id: r.id, day: day, amount: r.amount, reason: reason, ref: r.ref, xp: r.xp)
    }

    nonisolated static func sleepEntry(_ r: SleepRecord) -> SleepEntry? {
        guard let day = DayKey(r.wakeDay) else { return nil }
        return SleepEntry(wakeDay: day, bedtime: ClockTime(minutes: r.bedMinutes), wakeTime: ClockTime(minutes: r.wakeMinutes),
                          hoursSlept: r.hoursSlept, quality: r.quality)
    }

    nonisolated static func focusSession(_ r: FocusRecord) -> FocusSession? {
        guard let day = DayKey(r.day) else { return nil }
        return FocusSession(id: r.id, day: day, plannedMinutes: r.plannedMinutes, focusedMinutes: r.focusedMinutes,
                            lockedIn: r.lockedIn, note: r.note, habitID: r.habitID)
    }
}

enum SeedPlan {
    /// Tells the bundled plan apart from one synced from the coach.
    static let bundledGeneratedAt = load().generatedAt

    /// The coach plan bundled at build time (coach/tools/export_plan.py writes it).
    static func load() -> MasteryPlan {
        guard let url = Bundle.main.url(forResource: "seed-plan", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let plan = try? JSONDecoder().decode(MasteryPlan.self, from: data).validated() else {
            return MasteryPlan(generatedAt: "", weeklyFocus: nil, habits: [], notes: ["Seed plan missing from the app bundle."])
        }
        return plan
    }
}

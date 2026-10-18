#if DEBUG
import Foundation
import MasteryCore
import SwiftData

/// Release-gate test mode (Debug builds only). `--test-store <uuid>` runs on an in-memory store; the fixture JSON in
/// `MASTERY_TEST_FIXTURE` is replayed through the same store actions a person uses, so grit, streaks and the coach
/// see real history. Dates are relative to today, so a fixture never goes stale.
enum TestLaunch {
    static let isActive = ProcessInfo.processInfo.arguments.contains("--test-store")
    static let fixtureKey = "MASTERY_TEST_FIXTURE"

    struct Fixture: Decodable, Sendable {
        /// Per habit id, one letter per day ending today: F full, M min, S slipped, N not done, - nothing.
        var history: [String: String] = [:]
        var sleep: [Night] = []
        /// Focus sessions finished today, in minutes.
        var focusToday: [Int] = []

        struct Night: Decodable, Sendable {
            let daysAgo: Int
            let bed: String
            let wake: String
            let quality: Int?
        }

        /// Days of history, today included.
        var span: Int {
            max(1, history.values.map(\.count).max() ?? 1, (sleep.map(\.daysAgo).max() ?? 0) + 1)
        }

        enum CodingKeys: String, CodingKey { case history, sleep, focusToday }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            history = try c.decodeIfPresent([String: String].self, forKey: .history) ?? [:]
            sleep = try c.decodeIfPresent([Night].self, forKey: .sleep) ?? []
            focusToday = try c.decodeIfPresent([Int].self, forKey: .focusToday) ?? []
        }
    }

    /// A malformed fixture crashes on purpose: the tour reports a dead app instead of touring empty screens.
    static let fixture: Fixture? = {
        guard isActive, let json = ProcessInfo.processInfo.environment[fixtureKey] else { return nil }
        do { return try JSONDecoder().decode(Fixture.self, from: Data(json.utf8)) } catch {
            fatalError("Bad \(fixtureKey): \(error)")
        }
    }()

    /// Before the store loads: settings that start the history `span` days ago, with every plan habit live since then.
    @MainActor static func prepare(_ context: ModelContext) {
        guard let fixture else { return }
        let start = DayKey(date: .now).adding(days: -(fixture.span - 1))
        var settings = AppSettings.fresh(today: start)
        settings.soundOn = false
        for habit in SeedPlan.load().habits { settings.habitFirstSeen[habit.id] = start }
        do {
            context.insert(BlobRecord(key: BlobKey.settings, data: try JSONEncoder().encode(settings)))
            try context.save()
        } catch {
            fatalError("Test settings not saved: \(error)")
        }
    }

    /// SwiftUI may build RootView more than once; the fixture is replayed into the shared store only once.
    @MainActor private static var didSeed = false

    /// Replays the fixture oldest day first, as it would have happened.
    @MainActor static func seed(_ store: MasteryStore) {
        guard let fixture, !didSeed else { return }
        didSeed = true
        let today = store.today
        for daysAgo in stride(from: fixture.span - 1, through: 0, by: -1) {
            let day = today.adding(days: -daysAgo, timeZone: store.timeZone)
            for night in fixture.sleep where night.daysAgo == daysAgo {
                store.logSleep(SleepEntry(wakeDay: day, bedtime: clock(night.bed), wakeTime: clock(night.wake),
                                          quality: night.quality))
            }
            for (habitID, letters) in fixture.history.sorted(by: { $0.key < $1.key }) {
                let index = letters.count - 1 - daysAgo
                guard index >= 0, let level = level(Array(letters)[index]) else { continue }
                store.log(level, habitID: habitID, day: day)
            }
        }
        for minutes in fixture.focusToday {
            store.record(focus: FocusSession(day: today, plannedMinutes: minutes, focusedMinutes: minutes,
                                             lockedIn: false, habitID: "reset-focus"))
        }
        store.lastReward = nil
    }

    private static func level(_ letter: Character) -> CompletionLevel? {
        switch letter {
        case "F": return .full
        case "M": return .minimum
        case "S": return .slipped
        case "N": return .notDone
        default: return nil
        }
    }

    private static func clock(_ text: String) -> ClockTime {
        let parts = text.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { fatalError("Bad clock time in \(fixtureKey): \(text)") }
        return ClockTime(hour: parts[0], minute: parts[1])
    }
}
#endif

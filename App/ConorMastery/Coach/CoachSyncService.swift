import Foundation
import MasteryCore

/// Reads and writes the shared CoachSync iCloud folder (the same folder ConorHealth and Sunday use).
/// Rules from the coach-kb contract: atomic writes, skip *.tmp, never write to `to-apps/`.
struct CoachSyncService {
    private static let bookmarkKey = "coachsync.bookmark.v1"

    struct PullResult {
        var plan: MasteryPlan?
        var workouts: [Completion]
        var problems: [String]
    }

    enum SyncError: LocalizedError {
        case notConnected, accessDenied
        var errorDescription: String? {
            switch self {
            case .notConnected: return "Pick the CoachSync folder in Settings first."
            case .accessDenied: return "iOS refused access to the CoachSync folder. Pick it again in Settings."
            }
        }
    }

    var isConnected: Bool { UserDefaults.standard.data(forKey: Self.bookmarkKey) != nil }

    func connect(folder: URL) throws {
        guard folder.startAccessingSecurityScopedResource() else { throw SyncError.accessDenied }
        defer { folder.stopAccessingSecurityScopedResource() }
        let bookmark = try folder.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.set(bookmark, forKey: Self.bookmarkKey)
    }

    func disconnect() { UserDefaults.standard.removeObject(forKey: Self.bookmarkKey) }

    /// Plan from the coach + workouts ConorHealth logged in the last `days` days.
    func pull(since start: DayKey) throws -> PullResult {
        try withFolder { root in
            var result = PullResult(plan: nil, workouts: [], problems: [])
            let planURL = root.appendingPathComponent(CoachPaths.plan)
            if let data = read(planURL) {
                do {
                    result.plan = try JSONDecoder().decode(MasteryPlan.self, from: data).validated()
                } catch {
                    result.problems.append("plan.json ignored: \(error.localizedDescription)")
                }
            }
            let logsDir = root.appendingPathComponent(CoachPaths.conorHealthSessionLogs)
            let files = (try? FileManager.default.contentsOfDirectory(at: logsDir, includingPropertiesForKeys: nil)) ?? []
            for file in files where file.pathExtension == "json" {
                guard let data = read(file),
                      let log = try? JSONDecoder().decode(ConorHealthSessionLog.self, from: data),
                      log.date >= start, let workout = log.workoutCompletion() else { continue }
                result.workouts.append(workout)
            }
            return result
        }
    }

    func push(_ log: MasteryDailyLog) throws {
        try withFolder { root in
            let target = root.appendingPathComponent(CoachPaths.dailyLog)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try atomicWrite(try encoder.encode(log), to: target)
        }
    }

    // MARK: - Private

    private func withFolder<T>(_ body: (URL) throws -> T) throws -> T {
        guard let bookmark = UserDefaults.standard.data(forKey: Self.bookmarkKey) else { throw SyncError.notConnected }
        var stale = false
        let root = try URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &stale)
        guard root.startAccessingSecurityScopedResource() else { throw SyncError.accessDenied }
        defer { root.stopAccessingSecurityScopedResource() }
        if stale { try? connect(folder: root) }
        return try body(root)
    }

    /// iCloud may hold a placeholder; ask for the download and read what is there now.
    private func read(_ url: URL) -> Data? {
        guard !url.lastPathComponent.hasSuffix(".tmp") else { return nil }
        try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        var data: Data?
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { data = try? Data(contentsOf: $0) }
        return data
    }

    /// Contract rule: write `<name>.json.tmp` in the same folder, then rename over the final name.
    private func atomicWrite(_ data: Data, to target: URL) throws {
        let folder = target.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let temp = folder.appendingPathComponent(target.lastPathComponent + ".tmp")
        try data.write(to: temp)
        if FileManager.default.fileExists(atPath: target.path) {
            _ = try FileManager.default.replaceItemAt(target, withItemAt: temp)
        } else {
            try FileManager.default.moveItem(at: temp, to: target)
        }
    }
}

extension MasteryStore {
    /// Pull the plan and ConorHealth workouts, then push today's log. Errors land in `errorMessage`.
    func syncCoach(service: CoachSyncService = CoachSyncService()) {
        guard service.isConnected else { return }
        do {
            let pulled = try service.pull(since: today.adding(days: -14, timeZone: timeZone))
            if let plan = pulled.plan, plan != self.plan { replace(plan: plan) }
            // Oldest first so streak bonuses replay in order; a ConorHealth log upgrades a Min to full.
            for workout in pulled.workouts.sorted(by: { $0.day < $1.day })
            where index.completion(workout.habitID, on: workout.day)?.level != .full && state.habit(workout.habitID) != nil {
                log(.full, habitID: workout.habitID, day: workout.day, source: .conorhealth, minutes: workout.minutes)
            }
            try service.push(buildDailyLog())
            if !pulled.problems.isEmpty { errorMessage = pulled.problems.joined(separator: "\n") }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func buildDailyLog() -> MasteryDailyLog {
        let days = DayKey.range(today.adding(days: -30, timeZone: timeZone), through: today, timeZone: timeZone)
        let focusByDay = Dictionary(grouping: focus, by: \.day).mapValues { $0.reduce(0) { $0 + $1.focusedMinutes } }
        let outcomes = streak.outcomes
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = timeZone
        return DailyLogBuilder.build(days: days, completions: state.completions, sleep: sleep, target: settings.sleepTarget,
                                     focusMinutes: focusByDay, outcomes: outcomes, reflections: reflections,
                                     generatedAt: formatter.string(from: .now))
    }
}

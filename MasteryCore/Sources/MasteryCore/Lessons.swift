import Foundation

/// One coach tip: our own one-line paraphrase of a source, with its citation. Ships in the plan.
public struct Lesson: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let habitID: String
    public let text: String
    public let source: String
    public let locator: String

    public init(id: String, habitID: String, text: String, source: String, locator: String) {
        self.id = id; self.habitID = habitID; self.text = text; self.source = source; self.locator = locator
    }

    enum CodingKeys: String, CodingKey {
        case id, text, source, locator
        case habitID = "habit"
    }

    /// YouTube sources open at the cited moment (`mm:ss` or `h:mm:ss`); books and studies have no link.
    public var videoURL: URL? {
        guard source.hasPrefix("yt:") else { return nil }
        let parts = locator.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 || parts.count == 3, parts.count == locator.split(separator: ":").count else { return nil }
        let seconds = parts.reduce(0) { $0 * 60 + $1 }
        return URL(string: "https://www.youtube.com/watch?v=\(source.dropFirst(3))&t=\(seconds)s")
    }
}

public enum LessonStatus: String, Codable, Sendable {
    /// Tried and missed: comes back after `LessonPlanner.reviewAfterDays`.
    case learning
    /// You did it: never shown as the daily lesson again (still in the library).
    case kept
}

public struct LessonRecord: Codable, Sendable, Hashable {
    public let lastAnswered: DayKey
    public let status: LessonStatus
    public let misses: Int
}

/// Picks one lesson a day. Order: today's answered lesson (so the card stays put), then missed lessons
/// that are due again, then new lessons interleaved across habits in focus order.
/// An unanswered lesson stays today's lesson until you answer it.
public enum LessonPlanner {
    public static let reviewAfterDays = 3

    public static func pick(_ lessons: [Lesson], records: [String: LessonRecord], habitOrder: [String],
                            today: DayKey, timeZone: TimeZone = .current) -> Lesson? {
        if let answeredToday = lessons.first(where: { records[$0.id]?.lastAnswered == today }) {
            return answeredToday
        }
        let due = lessons.filter { lesson in
            guard let record = records[lesson.id], record.status == .learning else { return false }
            return record.lastAnswered.days(until: today, timeZone: timeZone) >= reviewAfterDays
        }
        if let oldest = due.min(by: { records[$0.id]!.lastAnswered < records[$1.id]!.lastAnswered }) {
            return oldest
        }
        // Interleave the full list so each lesson keeps its place in the rotation as others are answered.
        return interleaved(lessons, habitOrder: habitOrder).first { records[$0.id] == nil }
    }

    /// Record today's answer. Kept is final; a miss counts and schedules a review.
    public static func answering(_ records: [String: LessonRecord], lessonID: String, kept: Bool,
                                 on day: DayKey) -> [String: LessonRecord] {
        var next = records
        let misses = (records[lessonID]?.misses ?? 0) + (kept ? 0 : 1)
        next[lessonID] = LessonRecord(lastAnswered: day, status: kept ? .kept : .learning, misses: misses)
        return next
    }

    /// First lesson of each habit (focus order), then the second of each, and so on.
    static func interleaved(_ lessons: [Lesson], habitOrder: [String]) -> [Lesson] {
        func rank(_ habit: String) -> Int { habitOrder.firstIndex(of: habit) ?? habitOrder.count }
        var perHabit: [String: Int] = [:]
        let keyed = lessons.enumerated().map { offset, lesson -> (Int, Int, Int, Lesson) in
            let index = perHabit[lesson.habitID, default: 0]
            perHabit[lesson.habitID] = index + 1
            return (index, rank(lesson.habitID), offset, lesson)
        }
        return keyed.sorted { ($0.0, $0.1, $0.2) < ($1.0, $1.1, $1.2) }.map(\.3)
    }
}

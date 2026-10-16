import Foundation

/// A calendar day as `YYYY-MM-DD`, the same date format CoachSync uses.
public struct DayKey: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init?(_ rawValue: String) {
        guard DayKey.parse(rawValue) != nil else { return nil }
        self.rawValue = rawValue
    }

    public init(date: Date, timeZone: TimeZone = .current) {
        let parts = DayKey.calendar(timeZone).dateComponents([.year, .month, .day], from: date)
        rawValue = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    public var description: String { rawValue }

    public static func < (lhs: DayKey, rhs: DayKey) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Noon on this day in `timeZone` (noon avoids DST edge cases).
    public func date(timeZone: TimeZone = .current) -> Date {
        let (y, m, d) = DayKey.parse(rawValue)!
        var parts = DateComponents()
        parts.year = y; parts.month = m; parts.day = d; parts.hour = 12
        return DayKey.calendar(timeZone).date(from: parts)!
    }

    public func adding(days: Int, timeZone: TimeZone = .current) -> DayKey {
        let next = DayKey.calendar(timeZone).date(byAdding: .day, value: days, to: date(timeZone: timeZone))!
        return DayKey(date: next, timeZone: timeZone)
    }

    /// Calendar weekday, 1 = Sunday ... 7 = Saturday.
    public func weekday(timeZone: TimeZone = .current) -> Int {
        DayKey.calendar(timeZone).component(.weekday, from: date(timeZone: timeZone))
    }

    public func days(until other: DayKey, timeZone: TimeZone = .current) -> Int {
        let cal = DayKey.calendar(timeZone)
        return cal.dateComponents([.day], from: date(timeZone: timeZone), to: other.date(timeZone: timeZone)).day ?? 0
    }

    /// Inclusive range of days from `start` to `end`.
    public static func range(_ start: DayKey, through end: DayKey, timeZone: TimeZone = .current) -> [DayKey] {
        guard start <= end else { return [] }
        var out: [DayKey] = []
        var day = start
        while day <= end {
            out.append(day)
            day = day.adding(days: 1, timeZone: timeZone)
        }
        return out
    }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let key = DayKey(raw) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Bad date \(raw)"))
        }
        self = key
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    private static func parse(_ raw: String) -> (Int, Int, Int)? {
        let parts = raw.split(separator: "-")
        guard raw.count == 10, parts.count == 3,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
              (1...12).contains(m), (1...31).contains(d) else { return nil }
        // Round-trip through the calendar so 2026-02-31 is rejected instead of normalised.
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d; comps.hour = 12
        let cal = calendar(TimeZone(identifier: "UTC")!)
        guard let date = cal.date(from: comps) else { return nil }
        let back = cal.dateComponents([.year, .month, .day], from: date)
        guard back.year == y, back.month == m, back.day == d else { return nil }
        return (y, m, d)
    }

    private static func calendar(_ timeZone: TimeZone) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        return cal
    }
}

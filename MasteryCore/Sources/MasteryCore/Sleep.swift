import Foundation

/// Minutes after midnight, 0..<1440.
public struct ClockTime: Codable, Sendable, Hashable, Comparable {
    public let minutes: Int

    public init(hour: Int, minute: Int) {
        minutes = ((hour * 60 + minute) % 1440 + 1440) % 1440
    }

    public init(minutes: Int) {
        self.minutes = (minutes % 1440 + 1440) % 1440
    }

    public var hour: Int { minutes / 60 }
    public var minute: Int { minutes % 60 }

    /// "HH:mm".
    public var text: String { String(format: "%02d:%02d", hour, minute) }

    public init?(text: String) {
        let parts = text.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]),
              (0..<24).contains(h), (0..<60).contains(m) else { return nil }
        self.init(hour: h, minute: m)
    }

    public static func < (lhs: ClockTime, rhs: ClockTime) -> Bool { lhs.minutes < rhs.minutes }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let value = ClockTime(text: raw) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Bad time \(raw)"))
        }
        self = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(text)
    }
}

/// One night, keyed by the day you WOKE UP.
public struct SleepEntry: Codable, Sendable, Hashable {
    public let wakeDay: DayKey
    public let bedtime: ClockTime
    public let wakeTime: ClockTime
    /// Actual sleep, entered by hand. Nil = use time in bed.
    public let hoursSlept: Double?
    /// 1-5, optional.
    public let quality: Int?

    public init(wakeDay: DayKey, bedtime: ClockTime, wakeTime: ClockTime, hoursSlept: Double? = nil, quality: Int? = nil) {
        self.wakeDay = wakeDay; self.bedtime = bedtime; self.wakeTime = wakeTime
        self.hoursSlept = hoursSlept
        self.quality = quality.map { Swift.min(Swift.max($0, 1), 5) }
    }

    /// Real elapsed time in bed (handles DST nights); bed is the previous evening when bed >= wake.
    public func hoursInBed(timeZone: TimeZone = .current) -> Double {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let wakeDate = wakeDay.date(timeZone: timeZone)
        guard let wake = cal.date(bySettingHour: wakeTime.hour, minute: wakeTime.minute, second: 0, of: wakeDate),
              let bedSameDay = cal.date(bySettingHour: bedtime.hour, minute: bedtime.minute, second: 0, of: wakeDate) else {
            let delta = (wakeTime.minutes - bedtime.minutes + 1440) % 1440
            return Double(delta == 0 ? 1440 : delta) / 60
        }
        let bed = bedtime < wakeTime ? bedSameDay : cal.date(byAdding: .day, value: -1, to: bedSameDay) ?? bedSameDay
        return wake.timeIntervalSince(bed) / 3600
    }

    public var hoursInBed: Double { hoursInBed() }

    public var effectiveHours: Double { hoursSlept ?? hoursInBed }
}

public struct SleepTarget: Codable, Sendable, Hashable {
    public let bedtime: ClockTime
    public let hours: Double
    public let toleranceMinutes: Int

    public init(bedtime: ClockTime = ClockTime(hour: 22, minute: 30), hours: Double = 7.5, toleranceMinutes: Int = 30) {
        self.bedtime = bedtime; self.hours = hours; self.toleranceMinutes = toleranceMinutes
    }

    public func isOnTarget(_ entry: SleepEntry) -> Bool {
        let diff = abs(SleepStats.bedOffset(entry.bedtime) - SleepStats.bedOffset(bedtime))
        return diff <= toleranceMinutes && entry.effectiveHours >= hours
    }
}

public struct SleepStats: Sendable, Hashable {
    public let nights: Int
    public let averageHours: Double
    /// Standard deviation of bedtime in minutes (lower = more consistent).
    public let bedtimeSpreadMinutes: Double
    public let wakeSpreadMinutes: Double
    /// Target hours x nights - actual hours (positive = owed).
    public let debtHours: Double
    public let onTargetNights: Int

    /// Bedtime as minutes after noon so 23:30 and 00:30 sit next to each other.
    static func bedOffset(_ time: ClockTime) -> Int { (time.minutes - 720 + 1440) % 1440 }

    public static func compute(_ entries: [SleepEntry], target: SleepTarget) -> SleepStats? {
        guard !entries.isEmpty else { return nil }
        let hours = entries.map(\.effectiveHours)
        let total = hours.reduce(0, +)
        return SleepStats(
            nights: entries.count,
            averageHours: total / Double(entries.count),
            bedtimeSpreadMinutes: standardDeviation(entries.map { Double(bedOffset($0.bedtime)) }),
            wakeSpreadMinutes: standardDeviation(entries.map { Double($0.wakeTime.minutes) }),
            debtHours: target.hours * Double(entries.count) - total,
            onTargetNights: entries.filter(target.isOnTarget).count
        )
    }

    static func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(values.count)
        return variance.squareRoot()
    }
}

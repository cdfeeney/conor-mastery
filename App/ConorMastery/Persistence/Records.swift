import Foundation
import SwiftData

// SwiftData stores primitives only; MasteryCore value types are rebuilt by `MasteryStore`.

@Model final class CompletionRecord {
    var habitID: String
    var day: String
    var level: String
    var source: String
    var minutes: Int?
    var stepsDone: [String]
    var createdAt: Date

    init(habitID: String, day: String, level: String, source: String, minutes: Int?, stepsDone: [String]) {
        self.habitID = habitID; self.day = day; self.level = level; self.source = source
        self.minutes = minutes; self.stepsDone = stepsDone; self.createdAt = .now
    }
}

@Model final class LedgerRecord {
    @Attribute(.unique) var id: String
    var day: String
    var amount: Int
    var reason: String
    var ref: String
    var xp: Int
    var createdAt: Date

    init(id: String, day: String, amount: Int, reason: String, ref: String, xp: Int) {
        self.id = id; self.day = day; self.amount = amount; self.reason = reason
        self.ref = ref; self.xp = xp; self.createdAt = .now
    }
}

@Model final class SleepRecord {
    @Attribute(.unique) var wakeDay: String
    var bedMinutes: Int
    var wakeMinutes: Int
    var hoursSlept: Double?
    var quality: Int?

    init(wakeDay: String, bedMinutes: Int, wakeMinutes: Int, hoursSlept: Double?, quality: Int?) {
        self.wakeDay = wakeDay; self.bedMinutes = bedMinutes; self.wakeMinutes = wakeMinutes
        self.hoursSlept = hoursSlept; self.quality = quality
    }
}

@Model final class FocusRecord {
    @Attribute(.unique) var id: String
    var day: String
    var plannedMinutes: Int
    var focusedMinutes: Int
    var lockedIn: Bool
    var note: String?
    var habitID: String?
    var createdAt: Date

    init(id: String, day: String, plannedMinutes: Int, focusedMinutes: Int, lockedIn: Bool, note: String?, habitID: String?) {
        self.id = id; self.day = day; self.plannedMinutes = plannedMinutes; self.focusedMinutes = focusedMinutes
        self.lockedIn = lockedIn; self.note = note; self.habitID = habitID; self.createdAt = .now
    }
}

@Model final class TaskRecord {
    @Attribute(.unique) var id: String
    var title: String
    var day: String
    var isDone: Bool

    init(id: String = UUID().uuidString, title: String, day: String) {
        self.id = id; self.title = title; self.day = day; self.isDone = false
    }
}

@Model final class ReflectionRecord {
    @Attribute(.unique) var day: String
    var text: String

    init(day: String, text: String) {
        self.day = day; self.text = text
    }
}

/// JSON blobs: plan, world, settings.
@Model final class BlobRecord {
    @Attribute(.unique) var key: String
    var data: Data

    init(key: String, data: Data) {
        self.key = key; self.data = data
    }
}

enum Schema1 {
    static let models: [any PersistentModel.Type] = [
        CompletionRecord.self, LedgerRecord.self, SleepRecord.self, FocusRecord.self,
        TaskRecord.self, ReflectionRecord.self, BlobRecord.self
    ]
}

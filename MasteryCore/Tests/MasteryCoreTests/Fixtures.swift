import Foundation
@testable import MasteryCore

let utc = TimeZone(identifier: "UTC")!

func day(_ raw: String) -> DayKey { DayKey(raw)! }

func habit(_ id: String, _ difficulty: Difficulty = .medium, schedule: Schedule = .daily,
           kind: HabitKind = .build, target: Int? = nil, min: Int? = nil, challenges: [String] = []) -> HabitDefinition {
    HabitDefinition(id: id, title: id, kind: kind, difficulty: difficulty, group: .day, schedule: schedule,
                    identity: "I am someone who \(id)", full: "do \(id)", min: "a little \(id)",
                    targetMinutes: target, minMinutes: min, challenges: challenges)
}

func done(_ id: String, _ raw: String, _ level: CompletionLevel = .full) -> Completion {
    Completion(habitID: id, day: day(raw), level: level)
}

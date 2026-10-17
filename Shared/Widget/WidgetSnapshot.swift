import Foundation

/// What the home- and lock-screen widgets show. The app rewrites it (atomically) in the App Group after
/// every change; the widget only reads it. Foundation-only so the widget needs no MasteryCore.
struct WidgetSnapshot: Codable, Equatable {
    struct Item: Codable, Equatable {
        let title: String
        let isDone: Bool
    }

    /// yyyy-MM-dd in the phone's time zone. A snapshot from an earlier day means "not opened yet today".
    let day: String
    let streak: Int
    let grit: Int
    let level: Int
    /// Belt raw value ("white" ... "black") for the hero sprite.
    let belt: String
    let done: Int
    let required: Int
    let items: [Item]
    let lesson: String?
    /// True for a carried-over snapshot on a new day (the app hasn't published today's yet).
    var isNewDay = false

    /// `isNewDay` is worked out by the widget, never stored.
    enum CodingKeys: String, CodingKey {
        case day, streak, grit, level, belt, done, required, items, lesson
    }

    var nextOpen: String? { items.first { !$0.isDone }?.title }

    static let appGroup = "group.com.conorfee.conormastery"

    static var fileURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("widget-snapshot.json")
    }

    static func load() -> WidgetSnapshot? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    func save() throws {
        guard let url = Self.fileURL else { throw CocoaError(.fileNoSuchFile) }
        try JSONEncoder().encode(self).write(to: url, options: .atomic)
    }

    static func dayString(_ date: Date = .now, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// Seen on a later day before the app has run: keep streak, grit and belt, but no habit list,
    /// because today's schedule may differ from the one the snapshot was taken on.
    func asOf(_ today: String) -> WidgetSnapshot {
        guard today != day else { return self }
        return WidgetSnapshot(day: today, streak: streak, grit: grit, level: level, belt: belt, done: 0,
                              required: 0, items: [], lesson: nil, isNewDay: true)
    }

    static let placeholder = WidgetSnapshot(day: dayString(), streak: 12, grit: 340, level: 7, belt: "yellow",
                                            done: 5, required: 9,
                                            items: [Item(title: "Morning routine", isDone: true), Item(title: "Sleep", isDone: true),
                                                    Item(title: "Meditation", isDone: false), Item(title: "Workout", isDone: false)],
                                            lesson: nil)
}

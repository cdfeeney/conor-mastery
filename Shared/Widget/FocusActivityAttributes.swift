import ActivityKit
import Foundation

/// The focus session shown on the lock screen and in the Dynamic Island while a timer runs.
/// Shared by the app (starts/ends it) and the widget extension (draws it).
struct FocusActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let endsAt: Date
    }

    let startedAt: Date
    let plannedMinutes: Int
    let lockedIn: Bool
    /// Belt raw value for the hero sprite.
    let belt: String
    let note: String?
}

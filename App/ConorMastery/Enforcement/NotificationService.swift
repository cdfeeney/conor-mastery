import Foundation
import MasteryCore
import UserNotifications

/// Schedules today's reminders (habit cues, wind-down warning, streak at risk) from `ReminderPlanner`.
/// Rescheduled on launch, on foreground and after every habit change, so finished habits stop nagging.
@MainActor
final class NotificationService {
    private let center = UNUserNotificationCenter.current()
    private static let prefix = "mastery."

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func reschedule(_ reminders: [Reminder]) async {
        // The app schedules only its own reminders, so clearing all pending ones is safe and avoids
        // sending non-Sendable UNNotificationRequest arrays across actors (Swift 6).
        center.removeAllPendingNotificationRequests()
        for reminder in reminders {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: DateComponents(hour: reminder.time.hour, minute: reminder.time.minute), repeats: false)
            center.add(UNNotificationRequest(identifier: Self.prefix + reminder.id, content: content, trigger: trigger),
                       withCompletionHandler: nil)
        }
    }
}

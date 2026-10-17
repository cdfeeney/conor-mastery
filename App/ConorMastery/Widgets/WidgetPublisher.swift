import MasteryCore
import OSLog
import WidgetKit

/// Writes the widget snapshot after a change and asks WidgetKit to redraw, only when something visible changed.
@MainActor
enum WidgetPublisher {
    private static var lastPublished: WidgetSnapshot?
    private static let log = Logger(subsystem: "com.conorfee.conormastery", category: "widgets")

    static func publish(_ store: MasteryStore) {
        let snapshot = makeSnapshot(store)
        guard snapshot != lastPublished else { return }
        do {
            try snapshot.save()
            lastPublished = snapshot
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            // Widgets just stay on their last picture; the app itself is unaffected.
            log.error("Widget snapshot not saved: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func makeSnapshot(_ store: MasteryStore) -> WidgetSnapshot {
        // Only today's required habits, so the list matches the done/required count.
        let items = store.requiredToday.map { habit in
            WidgetSnapshot.Item(title: habit.title, isDone: store.index.isDone(habit.id, on: store.today))
        }
        return WidgetSnapshot(day: store.today.rawValue, streak: store.streak.current, grit: store.grit,
                              level: store.level.level, belt: store.level.belt.rawValue,
                              done: store.doneTodayCount, required: store.requiredToday.count,
                              // Open habits first, so the widget's short list shows what's left.
                              items: items.filter { !$0.isDone } + items.filter(\.isDone),
                              lesson: store.lesson?.text)
    }
}

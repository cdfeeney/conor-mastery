import MasteryCore
import SwiftUI

/// Top of Today: what still has to happen to keep the streak, each with its Min (owner 10-21: "there is a min
/// but I don't have a way to view that min condition").
struct StreakKeeperCard: View {
    @Environment(MasteryStore.self) private var store

    /// One line per open standalone habit, one per routine with steps left.
    private struct OpenItem: Identifiable {
        let id: String
        let title: String
        let min: String?
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(headline, systemImage: isSafe ? "checkmark.seal.fill" : "flame.fill")
                .font(.headline)
                .foregroundStyle(isSafe ? Theme.jade : Theme.accent)
            if !store.isRestDay && !items.isEmpty {
                Text("\(items.count) left · a Min counts").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title).font(.subheadline.weight(.semibold))
                        Text(item.min.map { "Min: \($0)" } ?? "No Min: do it in full")
                            .font(.caption).foregroundStyle(item.min == nil ? Theme.accent : .secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("streak-open-\(item.id)")
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("streak-keeper")
    }

    private var isSafe: Bool { store.isRestDay || items.isEmpty }

    private var headline: String {
        let days = store.streak.current
        if store.isRestDay { return "Rest day: streak paused" }
        if store.requiredToday.isEmpty { return "Nothing required today" }
        if items.isEmpty { return "Perfect Day: \(days)-day streak safe" }
        return days > 0 ? "Keep your \(days)-day streak" : "Start a streak today"
    }

    private var items: [OpenItem] {
        var seen = Set<String>()
        return store.streakOpen.compactMap { habit in
            guard let routineID = habit.routine else {
                return OpenItem(id: habit.id, title: habit.title, min: minText(habit))
            }
            guard seen.insert(routineID).inserted else { return nil }
            let left = store.streakOpen.filter { $0.routine == routineID }.count
            let routine = store.routine(routineID)
            return OpenItem(id: routineID, title: "\(routine?.title ?? "Routine") · \(left) step\(left == 1 ? "" : "s") left",
                            min: routine?.min)
        }
    }

    private func minText(_ habit: HabitDefinition) -> String? {
        if let min = habit.min { return min }
        if habit.kind == .avoid { return "stay clean, then tap Clean today" }
        return habit.minMinutes.map { "\($0) min" }
    }
}

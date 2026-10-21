import MasteryCore
import SwiftUI

/// The big row above a routine's steps: name, steps done, when/where, and the chevron that folds the steps away.
/// Each step below is its own habit (owner 10-20: one missed step is one miss, not the whole routine).
struct RoutineHeader: View {
    let routine: HabitDefinition
    let steps: [HabitDefinition]
    let isOpen: Bool
    let onToggle: () -> Void
    let onPlan: () -> Void
    @Environment(MasteryStore.self) private var store

    private var done: Int { steps.filter { store.index.isDone($0.id, on: store.today) }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: onToggle) {
                HStack {
                    Image(systemName: done == steps.count ? "checkmark.circle.fill" : "circle.dashed")
                        .foregroundStyle(done == steps.count ? Theme.jade : .secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(routine.title).font(.title3.weight(.bold))
                        Text("\(done) of \(steps.count) steps done").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: isOpen ? "chevron.up" : "chevron.down").font(.body.weight(.semibold))
                        .foregroundStyle(Theme.navy)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .tapTarget()
            .accessibilityLabel("\(routine.title), \(done) of \(steps.count) steps done")
            .accessibilityHint(isOpen ? "Hides the steps" : "Shows the steps")
            .accessibilityIdentifier("routine-\(routine.id)")
            Button(action: onPlan) {
                Label(store.settings.habitPlans[routine.id]?.cue ?? "Set when & where", systemImage: "clock")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(store.settings.habitPlans[routine.id] == nil ? Theme.navy : .secondary)
            .tapTarget()
            .accessibilityIdentifier("habit-plan-\(routine.id)")
            if let min = routine.min {
                Text("Min: \(min)").font(.caption).foregroundStyle(.secondary)
                    .accessibilityIdentifier("routine-min-\(routine.id)")
            }
        }
        .padding(.vertical, 4)
        // The whole routine in one swipe (owner 10-21); each step still swipes on its own.
        .swipeActions(edge: .leading) {
            Button("Done all") { store.logRoutine(.full, routineID: routine.id) }.tint(Theme.jade)
            if routine.min != nil { Button("Min") { store.logRoutine(.minimum, routineID: routine.id) }.tint(Theme.gold) }
        }
        .swipeActions(edge: .trailing) {
            if steps.contains(where: { store.completion($0.id) != nil }) {
                Button("Undo") { store.clearRoutine(routine.id) }.tint(.blue)
            }
        }
    }
}

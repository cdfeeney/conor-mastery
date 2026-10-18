import MasteryCore
import SwiftUI

/// "Your day": the whole plan on one page, built from the coach plan (no hardcoded copy).
/// Shown once on first launch, and any time from the Coach tab.
struct YourDayView: View {
    @Environment(MasteryStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Every habit has a Full version for normal days and a Min version for bad days. Min still keeps your streak.")
                    if let focus = store.weeklyFocus { Label(focus, systemImage: "scope").font(.subheadline.weight(.semibold)) }
                }
                ForEach(HabitGroup.allCases, id: \.self) { group in
                    let habits = store.habits(in: group)
                    if !habits.isEmpty {
                        Section(Self.title(group)) { ForEach(habits) { habit in row(habit) } }
                    }
                }
                Section {
                    Label("Each morning: one lesson on the Today tab. Each night: say if you did it.", systemImage: "graduationcap")
                    Label("Pin tips you want to follow as rules. They stay on the Coach tab.", systemImage: "pin")
                }
            }
            .navigationTitle("Your day")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Got it") { dismiss() }.accessibilityIdentifier("your-day-done") } }
        }
    }

    private func row(_ habit: HabitDefinition) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(habit.title).font(.headline)
            if habit.steps.isEmpty {
                Text("Full: \(habit.full)").font(.subheadline)
            } else {
                ForEach(Array(habit.steps.enumerated()), id: \.offset) { index, step in
                    Text("\(index + 1). \(step)").font(.subheadline)
                }
            }
            if let min = habit.min { Text("Min: \(min)").font(.caption).foregroundStyle(.secondary) }
        }
        .padding(.vertical, 2)
    }

    static func title(_ group: HabitGroup) -> String {
        switch group {
        case .morning: return "Morning"
        case .day: return "During the day"
        case .night: return "Night"
        }
    }
}

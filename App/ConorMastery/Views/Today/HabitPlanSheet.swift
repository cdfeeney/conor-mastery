import MasteryCore
import SwiftUI

/// "At [time] in [place], I will [habit]." Writing this down roughly doubles follow-through
/// (implementation intentions, res:gollwitzer2006). The time also drives today's reminder.
struct HabitPlanSheet: View {
    let habit: HabitDefinition
    @Environment(MasteryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var hasTime = true
    @State private var time = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: .now) ?? .now
    @State private var place = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Set a time", isOn: $hasTime)
                    if hasTime { DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute) }
                    TextField("Where (e.g. kitchen, gym, desk)", text: $place)
                } footer: {
                    Text("Writing down when and where you'll act makes you far more likely to follow through. If it isn't done by this time, you get a reminder.")
                }
                Section("Your plan") { Text(sentence).font(.headline) }
                if store.settings.habitPlans[habit.id] != nil {
                    Section {
                        Button("Clear plan", role: .destructive) { store.setPlan(nil, habitID: habit.id); dismiss() }
                    }
                }
            }
            .skyBackground()
            .navigationTitle(habit.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { store.setPlan(draft, habitID: habit.id); dismiss() }
                }
            }
            .onAppear(perform: load)
        }
    }

    private var draft: HabitPlan {
        HabitPlan(time: hasTime ? SettingsView.clock(time) : nil, place: place)
    }

    private var sentence: String {
        "\(draft.cue ?? "Some time today"), I will: \(habit.full.lowercased())."
    }

    private func load() {
        guard let saved = store.settings.habitPlans[habit.id] else { return }
        hasTime = saved.time != nil
        if let t = saved.time { time = SettingsView.date(t) }
        place = saved.place ?? ""
    }
}

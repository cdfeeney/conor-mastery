import MasteryCore
import SwiftUI

/// The coach's plan: weekly focus, why each habit matters (with sources), weakest habits,
/// and tonight's reflection (Monke's bonfire journal, adapted).
struct CoachView: View {
    @Environment(MasteryStore.self) private var store
    @State private var reflection = ""

    var body: some View {
        NavigationStack {
            List {
                if let focus = store.plan.weeklyFocus {
                    Section("This week") { Text(focus).font(.headline) }
                }
                if !store.plan.notes.isEmpty {
                    Section("Coach notes") { ForEach(store.plan.notes, id: \.self) { Text($0) } }
                }
                weakestSection
                Section("Your habits") {
                    ForEach(store.habits) { habit in
                        NavigationLink { HabitProtocolView(habit: habit) } label: {
                            VStack(alignment: .leading) {
                                Text(habit.title).font(.headline)
                                Text(habit.identity).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section("Tonight's reflection") {
                    TextField("What went well? What got in the way?", text: $reflection, axis: .vertical)
                        .lineLimit(3...8)
                    Button("Save reflection") { store.saveReflection(reflection) }
                        .disabled(reflection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Section {
                    Text(store.plan.generatedAt.isEmpty ? "Plan: bundled starter" : "Plan from coach: \(store.plan.generatedAt)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Coach")
            .refreshable { store.syncCoach() }
            .onAppear { reflection = store.reflections[store.today] ?? "" }
        }
    }

    @ViewBuilder private var weakestSection: some View {
        let weakest = store.consistency.prefix(3).filter { $0.rate < 1 }
        if !weakest.isEmpty {
            Section("Needs work (last 14 days)") {
                ForEach(weakest, id: \.habitID) { row in
                    HStack {
                        Text(store.state.habit(row.habitID)?.title ?? row.habitID)
                        Spacer()
                        Text("\(row.done)/\(row.required)").monospacedDigit().foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct HabitProtocolView: View {
    let habit: HabitDefinition

    var body: some View {
        List {
            Section("Identity") { Text(habit.identity).italic() }
            Section("Why") { Text(habit.why) }
            Section("Full") { Text(habit.full) }
            if let min = habit.min { Section("Minimum (bad days)") { Text(min) } }
            if !habit.steps.isEmpty {
                Section("Steps") { ForEach(habit.steps, id: \.self) { Text($0) } }
            }
            if !habit.citations.isEmpty {
                Section("Sources") {
                    ForEach(habit.citations, id: \.self) { citation in
                        if let url = Self.url(citation) {
                            Link("\(citation.source) @ \(citation.locator)", destination: url)
                        } else {
                            Text("\(citation.source) · \(citation.locator)")
                        }
                    }
                }
            }
        }
        .navigationTitle(habit.title)
    }

    /// `yt:<id>` + `mm:ss` deep-links to the moment in the video.
    static func url(_ citation: Citation) -> URL? {
        guard citation.source.hasPrefix("yt:") else { return nil }
        let id = citation.source.dropFirst(3)
        let parts = citation.locator.split(separator: ":").compactMap { Int($0) }
        let seconds = parts.reduce(0) { $0 * 60 + $1 }
        return URL(string: "https://www.youtube.com/watch?v=\(id)&t=\(seconds)s")
    }
}

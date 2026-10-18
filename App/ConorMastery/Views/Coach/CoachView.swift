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
                if let focus = store.weeklyFocus {
                    Section("This week") { Text(focus).font(.headline) }
                }
                if let advice = store.advice, !advice.notes.isEmpty {
                    Section("Coach says (from your last 14 days)") {
                        ForEach(advice.notes, id: \.self) { Label($0, systemImage: "bubble.left") }
                    }
                }
                if !store.plan.notes.isEmpty {
                    Section("Coach notes") { ForEach(store.plan.notes, id: \.self) { Text(SourceName.prose($0)) } }
                }
                weakestSection
                Section("Learn") {
                    NavigationLink { YourDayView() } label: { Label("Your day: the whole plan", systemImage: "sun.horizon") }
                        .accessibilityIdentifier("coach-your-day")
                    NavigationLink { TipLibraryView() } label: {
                        Label("Tip library · \(store.plan.lessons.count) tips", systemImage: "books.vertical")
                    }
                    .accessibilityIdentifier("coach-tip-library")
                }
                if !store.pinnedLessons.isEmpty {
                    Section("Your rules") { RulesList() }
                }
                Section("Your habits") {
                    ForEach(store.habits) { habit in
                        NavigationLink { HabitProtocolView(habit: habit) } label: {
                            VStack(alignment: .leading) {
                                Text(habit.title).font(.headline)
                                Text(habit.identity).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityIdentifier("coach-habit-\(habit.id)")
                    }
                }
                if store.lesson != nil {
                    Section("Tonight's check: today's lesson") { LessonCard() }
                }
                Section("Tonight's reflection") {
                    TextField("What went well? What got in the way?", text: $reflection, axis: .vertical)
                        .lineLimit(3...8)
                    Button("Save reflection") { store.saveReflection(reflection) }
                        .disabled(reflection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("coach-save-reflection")
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
    @Environment(MasteryStore.self) private var store

    var body: some View {
        List {
            Section("Identity") { Text(habit.identity).italic() }
            Section("Why") { Text(habit.why) }
            Section("Full") { Text(habit.full) }
            if let min = habit.min { Section("Minimum (bad days)") { Text(min) } }
            if !habit.steps.isEmpty {
                Section("Steps") { ForEach(habit.steps, id: \.self) { Text($0) } }
            }
            if store.pinnedLessons.contains(where: { $0.habitID == habit.id }) {
                Section("Your rules") { RulesList(habitID: habit.id) }
            }
            let tips = store.plan.lessons.filter { $0.habitID == habit.id }
            if !tips.isEmpty {
                Section("Tips · \(tips.count)") {
                    ForEach(tips) { lesson in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(lesson.text)
                            HStack(spacing: 16) { LessonSourceLink(lesson: lesson); PinButton(lessonID: lesson.id) }
                        }
                    }
                }
            }
            if !habit.citations.isEmpty {
                Section("Sources") {
                    ForEach(habit.citations, id: \.self) { citation in
                        if let url = Self.url(citation) {
                            Link("\(citation.source) @ \(citation.locator)", destination: url)
                        } else if citation.source.hasPrefix("res:") {
                            Label("Study: \(SourceName.readable(citation.source))", systemImage: "flask")
                        } else {
                            Text("\(SourceName.readable(citation.source)) · \(citation.locator)")
                        }
                    }
                }
            }
        }
        .navigationTitle(habit.title)
        .toolbar {
            if let planHabit = store.effectivePlanHabits.first(where: { $0.id == habit.id }) {
                NavigationLink("Edit") { HabitEditorView(habit: planHabit) }
            }
        }
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

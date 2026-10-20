import MasteryCore
import SwiftUI

/// Edit a habit on the phone: name, what counts as done, bad-day version, time of day, schedule,
/// difficulty, steps (routines) and minutes (timed habits). Coach habits keep their sources and can be reset.
struct HabitEditorView: View {
    let original: PlanHabit
    let isNew: Bool
    @Environment(MasteryStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var full: String
    @State private var min: String
    @State private var group: HabitGroup
    @State private var difficulty: Difficulty
    @State private var schedule: ScheduleChoice
    @State private var steps: [String]
    @State private var targetMinutes: Int
    @State private var minMinutes: Int
    @State private var problem: String?

    init(habit: PlanHabit, isNew: Bool = false) {
        original = habit
        self.isNew = isNew
        _title = State(initialValue: habit.title)
        _full = State(initialValue: habit.full)
        _min = State(initialValue: habit.min ?? "")
        _group = State(initialValue: habit.group)
        _difficulty = State(initialValue: habit.difficulty)
        _schedule = State(initialValue: ScheduleChoice(raw: habit.schedule))
        _steps = State(initialValue: habit.steps ?? [])
        _targetMinutes = State(initialValue: habit.targetMinutes ?? 10)
        _minMinutes = State(initialValue: habit.minMinutes ?? 2)
    }

    private var isCustom: Bool { original.id.hasPrefix(HabitEditor.customPrefix) }
    private var isEdited: Bool { store.settings.habitEdits[original.id] != nil }
    private var isTimed: Bool { original.kind == .timer || original.kind == .focus }

    var body: some View {
        Form {
            Section("Habit") {
                TextField("Name", text: $title)
                TextField("What counts as done", text: $full, axis: .vertical)
                TextField("Bad-day minimum (optional)", text: $min, axis: .vertical)
            }
            Section("When") {
                Picker("Time of day", selection: $group) {
                    Text("Morning").tag(HabitGroup.morning)
                    Text("Day").tag(HabitGroup.day)
                    Text("Night").tag(HabitGroup.night)
                }
                ScheduleEditor(schedule: $schedule)
                Picker("Difficulty", selection: $difficulty) {
                    ForEach(Difficulty.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }
            }
            if isTimed { minutesSection }
            if original.kind == .checklist { stepsSection }
            if let problem { Section { Text(problem).foregroundStyle(Theme.accent) } }
            if !isNew { removalSection }
        }
        .skyBackground()
        .navigationTitle(isNew ? "New habit" : "Edit habit")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) } }
    }

    private var minutesSection: some View {
        Section("Minutes") {
            Stepper("Full: \(targetMinutes) min", value: $targetMinutes, in: 1...180)
            Stepper("Minimum: \(minMinutes) min", value: $minMinutes, in: 1...max(1, targetMinutes))
        }
    }

    private var stepsSection: some View {
        Section {
            ForEach(steps.indices, id: \.self) { index in
                TextField("Step \(index + 1)", text: $steps[index])
            }
            .onDelete { steps.remove(atOffsets: $0) }
            .onMove { steps.move(fromOffsets: $0, toOffset: $1) }
            Button { steps.append("") } label: { Label("Add step", systemImage: "plus") }
        } header: {
            Text("Steps")
        } footer: {
            Text("The routine is done when every step is ticked.")
        }
    }

    @ViewBuilder private var removalSection: some View {
        if isCustom {
            Section {
                Button("Delete habit", role: .destructive) {
                    store.deleteCustomHabit(original.id)
                    dismiss()
                }
            } footer: { Text("Past days stay in your history.") }
        } else if isEdited {
            Section {
                Button("Reset to the coach's version") {
                    store.resetHabit(original.id)
                    dismiss()
                }
            }
        }
    }

    private func save() {
        if let issue = HabitEditor.problem(title: title, full: full) {
            problem = issue
            return
        }
        if original.kind == .checklist, steps.allSatisfy({ $0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            problem = "A routine needs at least one step."
            return
        }
        let habit = original.edited(title: title, full: full, min: min, group: group, difficulty: difficulty,
                                    schedule: schedule, steps: original.kind == .checklist ? steps : original.steps,
                                    targetMinutes: isTimed ? targetMinutes : original.targetMinutes,
                                    minMinutes: isTimed ? Swift.min(minMinutes, targetMinutes) : original.minMinutes)
        if isNew { store.addCustomHabit(habit) } else { store.saveHabit(habit) }
        dismiss()
    }
}

/// Daily, chosen weekdays, or N times a week.
struct ScheduleEditor: View {
    @Binding var schedule: ScheduleChoice

    private enum Mode: Hashable { case daily, weekdays, perWeek }

    private var mode: Binding<Mode> {
        Binding(get: {
            switch schedule {
            case .daily: return .daily
            case .weekdays: return .weekdays
            case .perWeek: return .perWeek
            }
        }, set: { mode in
            switch mode {
            case .daily: schedule = .daily
            case .weekdays: schedule = .weekdays([2, 3, 4, 5, 6])
            case .perWeek: schedule = .perWeek(3)
            }
        })
    }

    var body: some View {
        Picker("Repeat", selection: mode) {
            Text("Every day").tag(Mode.daily)
            Text("Chosen days").tag(Mode.weekdays)
            Text("Times a week").tag(Mode.perWeek)
        }
        switch schedule {
        case .daily:
            EmptyView()
        case .weekdays(let days):
            HStack {
                ForEach(1...7, id: \.self) { day in
                    let isOn = days.contains(day)
                    Button(Calendar.current.veryShortWeekdaySymbols[day - 1]) {
                        var next = days
                        if isOn { next.remove(day) } else { next.insert(day) }
                        if !next.isEmpty { schedule = .weekdays(next) }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(isOn ? Theme.navy : Color.clear, in: Circle())
                    .foregroundStyle(isOn ? .white : .primary)
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
        case .perWeek(let n):
            Stepper("\(n) times a week", value: Binding(get: { n }, set: { schedule = .perWeek($0) }), in: 1...7)
        }
    }
}

/// Pick the type, then fill in the editor.
struct NewHabitView: View {
    @Environment(MasteryStore.self) private var store
    @State private var kind: HabitKind = .build

    var body: some View {
        Form {
            Picker("Type", selection: $kind) {
                Text("Do it (tick once)").tag(HabitKind.build)
                Text("Avoid it all day").tag(HabitKind.avoid)
                Text("Routine (steps)").tag(HabitKind.checklist)
                Text("Timed").tag(HabitKind.timer)
            }
            .pickerStyle(.inline)
            NavigationLink("Next") { HabitEditorView(habit: draft, isNew: true) }
        }
        .skyBackground()
        .navigationTitle("Add a habit")
    }

    private var draft: PlanHabit {
        let taken = Set(store.effectivePlanHabits.map(\.id) + store.settings.retiredHabits.map(\.habit.id))
        return HabitEditor.newCustom(title: "", kind: kind, group: .day, full: "", existingIDs: taken)
    }
}

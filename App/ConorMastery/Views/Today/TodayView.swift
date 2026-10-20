import MasteryCore
import SwiftUI

/// The daily check-in: today's lesson, habit cards grouped Morning / Day / Night, then tasks.
struct TodayView: View {
    @Environment(MasteryStore.self) private var store
    @State private var newTask = ""
    @State private var timerHabit: HabitDefinition?
    /// One sheet for the screen, not one per card (nine presentation hosts slowed Today's first render).
    @State private var planHabit: HabitDefinition?
    @State private var showSleepLog = false
    @State private var showAddHabit = false

    var body: some View {
        NavigationStack {
            List {
                if !store.plan.lessons.isEmpty {
                    Section("Today's lesson") { LessonCard() }
                }
                ForEach(HabitGroup.allCases, id: \.self) { group in
                    let habits = store.habits(in: group)
                    if !habits.isEmpty {
                        Section(title(group)) {
                            ForEach(habits) { habit in
                                HabitCard(habit: habit, onTimer: { timerHabit = habit }, onSleep: { showSleepLog = true }, onPlan: { planHabit = habit })
                            }
                        }
                    }
                }
                tasksSection
            }
            .skyBackground()
            .navigationTitle(Date.now.formatted(.dateTime.weekday(.wide).month().day()))
            .sheet(item: $timerHabit) { habit in HabitTimerSheet(habit: habit) }
            .sheet(item: $planHabit) { habit in HabitPlanSheet(habit: habit) }
            .sheet(isPresented: $showSleepLog) { SleepLogSheet() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddHabit = true } label: { Label("Add a habit", systemImage: "plus") }
                        .accessibilityIdentifier("today-add-habit")
                }
            }
            .sheet(isPresented: $showAddHabit) {
                NavigationStack {
                    NewHabitView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { showAddHabit = false }.accessibilityIdentifier("add-habit-close")
                            }
                        }
                }
            }
            .overlay {
                if store.habits.isEmpty {
                    ContentUnavailableView("No habits yet", systemImage: "list.bullet.clipboard",
                                           description: Text("Connect the CoachSync folder in Settings to load your coach plan."))
                }
            }
        }
    }

    private func title(_ group: HabitGroup) -> String {
        switch group {
        case .morning: return "Morning"
        case .day: return "Day"
        case .night: return "Night"
        }
    }

    private var tasksSection: some View {
        Section("Tasks · +\(RewardRules.taskGrit) grit each") {
            ForEach(store.tasks.filter { $0.day == store.today.rawValue }) { task in
                HStack {
                    Button { store.toggle(task: task) } label: {
                        Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(task.isDone ? Theme.jade : .secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(task.isDone ? "Mark not done" : "Mark done")
                    Text(task.title).strikethrough(task.isDone)
                }
                .swipeActions { Button("Delete", role: .destructive) { store.delete(task: task) } }
            }
            HStack {
                TextField("Add task", text: $newTask).submitLabel(.done).onSubmit(addTask)
                Button("Add", action: addTask).buttonStyle(.bordered).disabled(newTask.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func addTask() {
        store.addTask(newTask)
        newTask = ""
    }
}

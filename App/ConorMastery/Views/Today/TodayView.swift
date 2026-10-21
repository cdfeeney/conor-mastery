import MasteryCore
import SwiftUI

/// The daily check-in: what keeps the streak, today's lesson, habit cards grouped Morning / Day / Night, then tasks.
struct TodayView: View {
    @Environment(MasteryStore.self) private var store
    @State private var newTask = ""
    @State private var timerHabit: HabitDefinition?
    /// One sheet for the screen, not one per card (nine presentation hosts slowed Today's first render).
    @State private var planHabit: HabitDefinition?
    @State private var showSleepLog = false
    @State private var showAddHabit = false
    @State private var showHistory = false
    /// Routines folded or unfolded by hand, against their default (open until every step is done).
    @State private var toggled: Set<String> = []

    var body: some View {
        NavigationStack {
            List {
                if !store.habits.isEmpty {
                    Section { StreakKeeperCard() }
                }
                if !store.plan.lessons.isEmpty {
                    Section("Today's lesson") { LessonCard() }
                }
                ForEach(HabitGroup.allCases, id: \.self) { group in
                    let habits = store.habits(in: group)
                    if !habits.isEmpty {
                        Section(title(group)) {
                            ForEach(habits) { habit in
                                if let routineID = habit.routine {
                                    let steps = habits.filter { $0.routine == routineID }
                                    if habit.id == steps.first?.id, let routine = store.planHabits.first(where: { $0.id == routineID }) {
                                        RoutineHeader(routine: routine, steps: steps, isOpen: isOpen(routineID, steps: steps),
                                                      onToggle: { toggled.formSymmetricDifference([routineID]) },
                                                      onPlan: { planHabit = routine })
                                    }
                                    if isOpen(routineID, steps: steps) {
                                        HabitCard(habit: habit, onTimer: {}, onSleep: {}, onPlan: {}, compact: true)
                                    }
                                } else {
                                    HabitCard(habit: habit, onTimer: { timerHabit = habit }, onSleep: { showSleepLog = true }, onPlan: { planHabit = habit })
                                }
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
            .sheet(isPresented: $showHistory) {
                NavigationStack {
                    HistoryView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { showHistory = false }.accessibilityIdentifier("history-close")
                            }
                        }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showHistory = true } label: { Label("History", systemImage: "square.grid.3x3.fill") }
                        .accessibilityIdentifier("today-history")
                }
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

    /// A routine shows its steps until they are all done, then folds; tapping its header flips that.
    private func isOpen(_ routineID: String, steps: [HabitDefinition]) -> Bool {
        let allDone = steps.allSatisfy { store.index.isDone($0.id, on: store.today) }
        return allDone == toggled.contains(routineID)
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
                .swipeActions(edge: .leading) {
                    Button(task.isDone ? "Undo" : "Done") { store.toggle(task: task) }.tint(task.isDone ? .blue : Theme.jade)
                }
                .swipeActions(edge: .trailing) { Button("Delete", role: .destructive) { store.delete(task: task) } }
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

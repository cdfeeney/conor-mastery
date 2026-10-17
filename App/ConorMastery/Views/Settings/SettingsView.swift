import FamilyControls
import MasteryCore
import SwiftUI

struct SettingsView: View {
    @Environment(MasteryStore.self) private var store
    @Environment(ScreenTimeService.self) private var screenTime
    @Environment(\.dismiss) private var dismiss
    @State private var showPicker = false
    @State private var showFolderPicker = false
    @State private var coachConnected = CoachSyncService().isConnected

    var body: some View {
        @Bindable var screenTime = screenTime
        NavigationStack {
            Form {
                screenTimeSection
                gateSection
                sleepSection
                Section {
                    Toggle("Today is a rest day", isOn: Binding(get: { store.isRestDay }, set: { _ in store.toggleRestDay() }))
                } header: {
                    Text("Rest")
                } footer: {
                    Text("Sick or travelling? Nothing is required today: streak, habit strength and energy pause. \(RestRules.perMonth) per month.")
                }
                Section("Streak") {
                    Toggle("Strict streak (no Second Winds)", isOn: setting(\.strictStreak))
                    Toggle("Reward sounds", isOn: setting(\.soundOn))
                    LabeledContent("Second Winds", value: "\(store.streak.secondWinds)")
                    LabeledContent("Best streak", value: "\(store.streak.best) days")
                }
                coachSection
                Section {
                    ForEach(store.effectivePlanHabits, id: \.id) { habit in
                        NavigationLink { HabitEditorView(habit: habit) } label: {
                            HStack {
                                Text(habit.title)
                                if store.settings.habitEdits[habit.id] != nil { Text("edited").font(.caption2).foregroundStyle(.secondary) }
                            }
                        }
                    }
                    NavigationLink { NewHabitView() } label: { Label("Add a habit", systemImage: "plus") }
                } header: {
                    Text("Edit habits")
                } footer: {
                    Text("Your changes win over the coach's plan until you reset them.")
                }
                Section("Habits on / off") {
                    ForEach(store.effectivePlanHabits, id: \.id) { habit in
                        Toggle(habit.title, isOn: Binding(
                            get: { store.settings.archivedHabits[habit.id] == nil },
                            set: { on in
                                var s = store.settings
                                if on {
                                    // Re-enabled habits count again from today, not retroactively.
                                    s.archivedHabits[habit.id] = nil
                                    s.habitFirstSeen[habit.id] = store.today
                                } else {
                                    s.archivedHabits[habit.id] = store.today
                                }
                                store.update(settings: s)
                            }))
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .familyActivityPicker(isPresented: $showPicker, selection: $screenTime.selection)
            .onChange(of: screenTime.selection) { _, _ in
                screenTime.saveSelection()
                screenTime.apply(store: store)
            }
            .fileImporter(isPresented: $showFolderPicker, allowedContentTypes: [.folder]) { result in
                connectFolder(result)
            }
        }
    }

    private var screenTimeSection: some View {
        Section {
            if screenTime.isAuthorized {
                Button(screenTime.hasSelection ? "Change blocked apps" : "Choose apps to block") { showPicker = true }
            } else {
                Button("Allow Screen Time") { Task { await screenTime.requestAuthorization() } }
            }
            if let error = screenTime.lastError { Text(error).font(.caption).foregroundStyle(Theme.accent) }
        } header: {
            Text("Enforcement")
        } footer: {
            Text("Blocked apps lock at wind-down and stay locked until your morning routine is done. Unlock early for \(RewardRules.unblockGritCost) grit (logged as a slip).")
        }
    }

    private var gateSection: some View {
        Section("Gate") {
            Toggle("Morning gate", isOn: gateSetting(\.enabled))
            DatePicker("Wind-down", selection: windDownBinding, displayedComponents: .hourAndMinute)
            Toggle("No social media outside window", isOn: gateSetting(\.noSocialSchedule))
            LabeledContent("Status", value: store.gateDecision().message)
            Button("Unlock 15 min for \(RewardRules.unblockGritCost) grit") { screenTime.startUnblock(store: store) }
                .disabled(!store.gateDecision().shield || store.grit < RewardRules.unblockGritCost)
        }
    }

    private var sleepSection: some View {
        Section("Sleep target") {
            DatePicker("Bedtime", selection: sleepBedtime, displayedComponents: .hourAndMinute)
            Stepper(String(format: "%.1f hours", store.settings.sleepTarget.hours), value: sleepHours, in: 5...10, step: 0.25)
        }
    }

    private var coachSection: some View {
        Section {
            if coachConnected {
                Button("Sync now") { store.syncCoach() }
                Button("Disconnect folder", role: .destructive) { CoachSyncService().disconnect(); coachConnected = false }
            } else {
                Button("Pick CoachSync folder") { showFolderPicker = true }
            }
        } header: {
            Text("Coach")
        } footer: {
            Text("The iCloud Drive CoachSync folder shared with ConorHealth and Sunday. Workouts logged in ConorHealth tick your Workout habit.")
        }
    }

    // MARK: - Bindings (settings are immutable values; each edit writes a new copy)

    private func setting<T>(_ path: WritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding(get: { store.settings[keyPath: path] },
                set: { var s = store.settings; s[keyPath: path] = $0; store.update(settings: s) })
    }

    private func gateSetting(_ path: KeyPath<GateConfig, Bool>) -> Binding<Bool> {
        Binding(get: { store.settings.gate[keyPath: path] }, set: { value in
            let g = store.settings.gate
            var s = store.settings
            s.gate = GateConfig(enabled: path == \.enabled ? value : g.enabled, windDown: g.windDown,
                                morningHabitID: g.morningHabitID,
                                noSocialSchedule: path == \.noSocialSchedule ? value : g.noSocialSchedule,
                                allowedWindows: g.allowedWindows)
            store.update(settings: s)
            screenTime.apply(store: store)
        })
    }

    private var windDownBinding: Binding<Date> {
        Binding(get: { Self.date(store.settings.gate.windDown) }, set: { date in
            let g = store.settings.gate
            var s = store.settings
            s.gate = GateConfig(enabled: g.enabled, windDown: Self.clock(date), morningHabitID: g.morningHabitID,
                                noSocialSchedule: g.noSocialSchedule, allowedWindows: g.allowedWindows)
            store.update(settings: s)
            screenTime.apply(store: store)
        })
    }

    private var sleepBedtime: Binding<Date> {
        Binding(get: { Self.date(store.settings.sleepTarget.bedtime) }, set: { date in
            var s = store.settings
            s.sleepTarget = SleepTarget(bedtime: Self.clock(date), hours: s.sleepTarget.hours, toleranceMinutes: s.sleepTarget.toleranceMinutes)
            store.update(settings: s)
        })
    }

    private var sleepHours: Binding<Double> {
        Binding(get: { store.settings.sleepTarget.hours }, set: { hours in
            var s = store.settings
            s.sleepTarget = SleepTarget(bedtime: s.sleepTarget.bedtime, hours: hours, toleranceMinutes: s.sleepTarget.toleranceMinutes)
            store.update(settings: s)
        })
    }

    private func connectFolder(_ result: Result<URL, Error>) {
        do {
            try CoachSyncService().connect(folder: try result.get())
            coachConnected = true
            store.syncCoach()
        } catch {
            store.errorMessage = error.localizedDescription
        }
    }

    static func date(_ time: ClockTime) -> Date {
        Calendar.current.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: .now) ?? .now
    }

    static func clock(_ date: Date) -> ClockTime {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return ClockTime(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
    }
}

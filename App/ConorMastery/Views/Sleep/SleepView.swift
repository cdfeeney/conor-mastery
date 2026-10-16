import Charts
import MasteryCore
import SwiftUI

/// Manual sleep log: bedtime, wake time, hours actually slept. Stats over the last 7 nights.
struct SleepView: View {
    @Environment(MasteryStore.self) private var store
    @State private var showLog = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { showLog = true } label: { Label("Log last night", systemImage: "plus.circle.fill") }
                        .font(.headline)
                }
                if let stats = store.sleepStats { statsSection(stats) }
                if !store.sleep.isEmpty { chartSection }
                Section("Nights") {
                    ForEach(store.sleep.reversed(), id: \.wakeDay) { entry in
                        HStack {
                            Text(entry.wakeDay.date().formatted(.dateTime.weekday(.abbreviated).month().day()))
                            Spacer()
                            Text("\(entry.bedtime.text) → \(entry.wakeTime.text)").foregroundStyle(.secondary)
                            Text(String(format: "%.1fh", entry.effectiveHours)).monospacedDigit()
                                .foregroundStyle(store.settings.sleepTarget.isOnTarget(entry) ? Theme.jade : .primary)
                        }
                        .font(.subheadline)
                    }
                }
            }
            .navigationTitle("Sleep")
            .sheet(isPresented: $showLog) { SleepLogSheet() }
            .overlay {
                if store.sleep.isEmpty {
                    ContentUnavailableView("No nights logged", systemImage: "moon.zzz",
                                           description: Text("Log bedtime, wake time and how long you slept."))
                }
            }
        }
    }

    private func statsSection(_ stats: SleepStats) -> some View {
        Section("Last 7 nights") {
            LabeledContent("Average", value: String(format: "%.1f h", stats.averageHours))
            LabeledContent("On target", value: "\(stats.onTargetNights)/\(stats.nights)")
            LabeledContent("Bedtime spread", value: "±\(Int(stats.bedtimeSpreadMinutes)) min")
            LabeledContent("Wake spread", value: "±\(Int(stats.wakeSpreadMinutes)) min")
            LabeledContent(stats.debtHours >= 0 ? "Sleep debt" : "Ahead", value: String(format: "%.1f h", abs(stats.debtHours)))
        }
    }

    private var chartSection: some View {
        let target = store.settings.sleepTarget.hours
        return Section("Hours (14 nights)") {
            Chart {
                ForEach(store.sleep.suffix(14), id: \.wakeDay) { entry in
                    BarMark(x: .value("Night", entry.wakeDay.date(), unit: .day), y: .value("Hours", entry.effectiveHours))
                        .foregroundStyle(store.settings.sleepTarget.isOnTarget(entry) ? Theme.jade : Theme.accent.opacity(0.7))
                }
                RuleMark(y: .value("Target", target)).lineStyle(StrokeStyle(dash: [4])).foregroundStyle(.secondary)
            }
            .frame(height: 180)
            .accessibilityLabel("Sleep hours for the last 14 nights, target \(target) hours")
        }
    }
}

struct SleepLogSheet: View {
    @Environment(MasteryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var wakeDay = Date.now
    @State private var bedtime = Calendar.current.date(bySettingHour: 22, minute: 30, second: 0, of: .now) ?? .now
    @State private var wakeTime = Calendar.current.date(bySettingHour: 6, minute: 30, second: 0, of: .now) ?? .now
    @State private var overrideHours = false
    @State private var hoursSlept = 7.0
    @State private var quality = 3

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Woke up on", selection: $wakeDay, in: ...Date.now, displayedComponents: .date)
                DatePicker("Went to bed", selection: $bedtime, displayedComponents: .hourAndMinute)
                DatePicker("Woke up at", selection: $wakeTime, displayedComponents: .hourAndMinute)
                LabeledContent("Time in bed", value: String(format: "%.1f h", draft.hoursInBed))
                Toggle("Slept less than time in bed", isOn: $overrideHours)
                if overrideHours {
                    Stepper(String(format: "Actually slept %.1f h", hoursSlept), value: $hoursSlept, in: 0...14, step: 0.25)
                }
                Picker("Quality", selection: $quality) {
                    ForEach(1...5, id: \.self) { Text(String(repeating: "★", count: $0)).tag($0) }
                }
                Section {
                    let onTarget = store.settings.sleepTarget.isOnTarget(draft)
                    Label(onTarget ? "On target: full habit" : "Logged: counts as minimum",
                          systemImage: onTarget ? "checkmark.seal.fill" : "circle.lefthalf.filled")
                        .foregroundStyle(onTarget ? Theme.jade : Theme.gold)
                }
            }
            .navigationTitle("Log sleep")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { store.logSleep(draft); dismiss() } }
            }
            .onAppear(perform: prefill)
        }
    }

    private var draft: SleepEntry {
        SleepEntry(wakeDay: DayKey(date: wakeDay), bedtime: clock(bedtime), wakeTime: clock(wakeTime),
                   hoursSlept: overrideHours ? hoursSlept : nil, quality: quality)
    }

    private func clock(_ date: Date) -> ClockTime {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return ClockTime(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
    }

    /// Editing today's entry starts from what was saved.
    private func prefill() {
        guard let saved = store.sleep.first(where: { $0.wakeDay == store.today }) else { return }
        bedtime = Calendar.current.date(bySettingHour: saved.bedtime.hour, minute: saved.bedtime.minute, second: 0, of: .now) ?? bedtime
        wakeTime = Calendar.current.date(bySettingHour: saved.wakeTime.hour, minute: saved.wakeTime.minute, second: 0, of: .now) ?? wakeTime
        if let hours = saved.hoursSlept { overrideHours = true; hoursSlept = hours }
        quality = saved.quality ?? 3
    }
}

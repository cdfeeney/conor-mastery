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
                        .accessibilityIdentifier("sleep-log")
                        .font(.headline)
                }
                if let stats = store.sleepStats { statsSection(stats) }
                if !store.sleep.isEmpty { chartSection }
                if store.sleep.isEmpty {
                    // In the list, not an overlay: an overlay sat on top of "Log last night" on day one.
                    Section("Nights") {
                        ContentUnavailableView("No nights logged", systemImage: "moon.zzz",
                                               description: Text("Log bedtime, wake time and how long you slept."))
                    }
                }
                // One section per month, newest first: months of nights in one list had no landmarks.
                ForEach(nightsByMonth, id: \.title) { month in
                    Section(month.title) { ForEach(month.nights, id: \.wakeDay) { nightRow($0) } }
                }
            }
            .skyBackground()
            .navigationTitle("Sleep")
            .sheet(isPresented: $showLog) { SleepLogSheet() }
        }
    }

    private struct Month { let title: String; var nights: [SleepEntry] }

    private var nightsByMonth: [Month] {
        var months: [Month] = []
        for entry in store.sleep.reversed() {
            let title = entry.wakeDay.date().formatted(.dateTime.month(.wide).year())
            if months.last?.title == title { months[months.count - 1].nights.append(entry) } else { months.append(Month(title: title, nights: [entry])) }
        }
        return months
    }

    private func nightRow(_ entry: SleepEntry) -> some View {
        HStack {
            Text(entry.wakeDay.date().formatted(.dateTime.weekday(.abbreviated).month().day()))
            Spacer()
            Text("\(entry.bedtime.text) → \(entry.wakeTime.text)").foregroundStyle(.secondary)
            Text(String(format: "%.1fh", entry.effectiveHours)).monospacedDigit()
                .foregroundStyle(store.settings.sleepTarget.isOnTarget(entry) ? Theme.jade : .primary)
        }
        .font(.subheadline)
    }

    private func statsSection(_ stats: SleepStats) -> some View {
        Section("Last 7 nights") {
            LabeledContent("Average", value: String(format: "%.1f h", stats.averageHours))
            // Say what "on target" means: a 7.9 h night after a 23:40 bedtime is off target, and red bars
            // with no reason read as a bug.
            let target = store.settings.sleepTarget
            LabeledContent("On target", value: "\(stats.onTargetNights)/\(stats.nights)")
            Text("On target = in bed by \(target.bedtime.text) (±\(target.toleranceMinutes) min) and \(String(format: "%.1f", target.hours)) h or more.")
                .font(.caption).foregroundStyle(.secondary)
            LabeledContent("Bedtime spread", value: "±\(Int(stats.bedtimeSpreadMinutes)) min")
            LabeledContent("Wake spread", value: "±\(Int(stats.wakeSpreadMinutes)) min")
            LabeledContent(stats.debtHours >= 0 ? "Sleep debt" : "Ahead", value: String(format: "%.1f h", abs(stats.debtHours)))
        }
    }

    /// Plain bars, not Swift Charts: the first Charts render cost 1.5-5 s per process on the gate's simulator
    /// (run 39158232302: saving the first night took 7.7 s), and 14 bars need no chart engine.
    private var chartSection: some View {
        let target = store.settings.sleepTarget.hours
        let nights = Array(store.sleep.suffix(14))
        let top = max(target, nights.map(\.effectiveHours).max() ?? target, 1)
        let height: CGFloat = 150
        return Section(nights.count == 1 ? "Hours (1 night so far)" : "Hours (last \(nights.count) nights)") {
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(nights, id: \.wakeDay) { entry in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(store.settings.sleepTarget.isOnTarget(entry) ? Theme.jade : Theme.accent.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .frame(height: height * entry.effectiveHours / top)
                }
            }
            .frame(height: height, alignment: .bottom)
            .overlay(alignment: .bottom) {
                Rectangle().fill(.secondary).frame(height: 1).offset(y: -height * target / top)
            }
            .padding(.vertical, 6)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Sleep hours for the last \(nights.count) nights, target \(String(format: "%.1f", target)) hours")
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
            .skyBackground()
            .navigationTitle("Log sleep")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.accessibilityIdentifier("sleep-cancel") }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { store.logSleep(draft); dismiss() }.buttonStyle(.borderedProminent).accessibilityIdentifier("sleep-save") }
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

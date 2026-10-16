import MasteryCore
import SwiftUI

/// Countdown for timer habits (meditation, breathing). Deep breathing shows a 4-4-4-4 box pacer.
/// Minutes credit even if stopped early, so a short sit still counts toward the minimum.
struct HabitTimerSheet: View {
    let habit: HabitDefinition
    @Environment(MasteryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var startedAt: Date?
    @State private var minutes: Int

    init(habit: HabitDefinition) {
        self.habit = habit
        _minutes = State(initialValue: habit.targetMinutes ?? 10)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Text(habit.full).font(.headline).multilineTextAlignment(.center)
                if let startedAt {
                    TimelineView(.periodic(from: startedAt, by: 0.25)) { context in
                        let elapsed = context.date.timeIntervalSince(startedAt)
                        VStack(spacing: 24) {
                            if habit.id == "deep-breathing" { BoxBreathPacer(elapsed: elapsed) }
                            Text(remaining(elapsed)).font(.system(size: 64, weight: .bold, design: .rounded).monospacedDigit())
                        }
                        .onChange(of: elapsed >= Double(minutes * 60)) { _, finished in if finished { finish() } }
                    }
                    Button("Stop and save", role: .destructive) { finish() }.buttonStyle(.bordered)
                } else {
                    Stepper("\(minutes) min", value: $minutes, in: 1...60).font(.title3).padding(.horizontal, 40)
                    if let min = habit.minMinutes { Text("\(min) min counts as your minimum.").font(.caption).foregroundStyle(.secondary) }
                    Button { startedAt = .now } label: { Label("Start", systemImage: "play.fill").frame(maxWidth: 200) }
                        .buttonStyle(.borderedProminent).tint(Theme.jade).controlSize(.large)
                }
                Spacer()
            }
            .padding(.top, 32)
            .navigationTitle(habit.title)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .interactiveDismissDisabled(startedAt != nil)
        }
    }

    private func remaining(_ elapsed: TimeInterval) -> String {
        let left = max(Double(minutes * 60) - elapsed, 0)
        return String(format: "%d:%02d", Int(left) / 60, Int(left) % 60)
    }

    private func finish() {
        guard let startedAt else { return }
        let done = min(Int(Date.now.timeIntervalSince(startedAt) / 60), minutes)
        self.startedAt = nil
        store.finishTimer(habit: habit, minutes: done)
        dismiss()
    }
}

/// Box breathing: inhale 4 s, hold 4 s, exhale 4 s, hold 4 s.
struct BoxBreathPacer: View {
    let elapsed: TimeInterval

    var body: some View {
        let phase = Int(elapsed / 4) % 4
        let progress = elapsed.truncatingRemainder(dividingBy: 4) / 4
        let scale: Double = switch phase {
        case 0: 0.5 + 0.5 * progress
        case 1: 1
        case 2: 1 - 0.5 * progress
        default: 0.5
        }
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 24).fill(Theme.jade.opacity(0.35))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Theme.jade, lineWidth: 3))
                .frame(width: 180, height: 180).scaleEffect(scale)
                .animation(.linear(duration: 0.25), value: scale)
            Text(["Breathe in", "Hold", "Breathe out", "Hold"][phase]).font(.title3.weight(.semibold))
        }
        .accessibilityElement(children: .combine)
    }
}

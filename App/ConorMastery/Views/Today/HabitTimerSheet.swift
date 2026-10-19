import MasteryCore
import SwiftUI

/// Countdown for timer habits (meditation, breathing). Deep breathing shows a cyclic-sighing pacer.
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
                            if habit.id == "deep-breathing" { CyclicSighPacer(elapsed: elapsed) }
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
            .skyBackground()
            .navigationTitle(habit.title)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() }.tint(.white) } }
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

/// Cyclic sighing (Balban et al. 2023): long nose inhale, short top-up inhale, long mouth exhale.
struct CyclicSighPacer: View {
    let elapsed: TimeInterval

    /// Seconds per phase: inhale, top-up, exhale. The exhale is the longest part.
    private static let phases: [(label: String, seconds: Double)] = [("Breathe in", 2.5), ("Top up", 1), ("Long exhale", 6)]
    private static let cycle = phases.reduce(0) { $0 + $1.seconds }

    /// Which phase `elapsed` falls in, and how far through it (0...1).
    static func position(_ elapsed: TimeInterval) -> (phase: Int, progress: Double) {
        var t = elapsed.truncatingRemainder(dividingBy: cycle)
        var phase = 0
        while phase < phases.count - 1 && t >= phases[phase].seconds {
            t -= phases[phase].seconds
            phase += 1
        }
        return (phase, t / phases[phase].seconds)
    }

    var body: some View {
        let (phase, progress) = Self.position(elapsed)
        let scale: Double = switch phase {
        case 0: 0.5 + 0.4 * progress
        case 1: 0.9 + 0.1 * progress
        default: 1 - 0.5 * progress
        }
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 24).fill(Theme.jade.opacity(0.35))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Theme.jade, lineWidth: 3))
                .frame(width: 180, height: 180).scaleEffect(scale)
                .animation(.linear(duration: 0.25), value: scale)
            Text(Self.phases[phase].label).font(.title3.weight(.semibold))
        }
        .accessibilityElement(children: .combine)
    }
}

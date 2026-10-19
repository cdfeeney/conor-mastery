import MasteryCore
import SwiftUI

/// One habit: identity line, Min version, 7-day strip, reward, and the action that fits its kind.
struct HabitCard: View {
    let habit: HabitDefinition
    let onTimer: () -> Void
    let onSleep: () -> Void
    let onPlan: () -> Void
    @Environment(MasteryStore.self) private var store
    @State private var expanded = false

    private var completion: Completion? { store.completion(habit.id) }
    private var level: CompletionLevel? { completion?.level }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            Text(habit.identity).font(.subheadline.italic()).foregroundStyle(.secondary)
            Button { onPlan() } label: {
                Label(store.settings.habitPlans[habit.id]?.cue ?? "Set when & where", systemImage: "clock")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(store.settings.habitPlans[habit.id] == nil ? Theme.accent : .secondary)
            .accessibilityIdentifier("habit-plan-\(habit.id)")
            if let min = habit.min { Text("Min: \(min)").font(.caption).foregroundStyle(.secondary) }
            if habit.kind == .checklist && (expanded || level == nil) { checklist }
            HStack {
                WeekStrip(entries: store.weekStrip(habit.id))
                Spacer()
                actions
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture { expanded.toggle() }
        .swipeActions(edge: .leading) {
            Button("Done") { store.log(.full, habitID: habit.id) }.tint(Theme.jade)
            if habit.min != nil { Button("Min") { store.log(.minimum, habitID: habit.id) }.tint(Theme.gold) }
        }
        .swipeActions(edge: .trailing) {
            if habit.kind == .avoid {
                Button("Slipped") { store.log(.slipped, habitID: habit.id) }.tint(Theme.accent)
            } else {
                Button("Not done") { store.log(.notDone, habitID: habit.id) }.tint(.gray)
            }
            if completion != nil { Button("Undo") { store.clear(habitID: habit.id) }.tint(.blue) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("habit-\(habit.id)")
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            statusIcon
            Text(habit.title).font(.headline)
            if habit.kind == .avoid {
                Text("\(store.cleanDays(habit.id))d clean").font(.caption.weight(.semibold)).foregroundStyle(Theme.jade)
            }
            if let week = store.weeklyProgress(habit) {
                Text("\(week.done)/\(week.target) this week")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(week.isMet ? Theme.jade : week.isAtRisk ? Theme.accent : .secondary)
            }
            if completion?.source == .conorhealth {
                Label("ConorHealth", systemImage: "link").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            TierBadge(tier: store.tier(habit.id), multiplier: store.multiplier(habit.id))
            Label("\(price)", systemImage: "seal.fill")
                .font(.caption.monospacedDigit()).foregroundStyle(Theme.gold)
                .accessibilityLabel("\(price) grit")
        }
    }

    private var statusIcon: some View {
        let (symbol, color): (String, Color) = switch level {
        case .full: ("checkmark.circle.fill", Theme.jade)
        case .minimum: ("circle.lefthalf.filled", Theme.gold)
        case .slipped: ("xmark.circle.fill", Theme.accent)
        case .notDone: ("minus.circle", .gray)
        case nil: ("circle", .secondary)
        }
        return Image(systemName: symbol).foregroundStyle(color)
            .accessibilityLabel(level.map { "Status \($0.rawValue)" } ?? "Not logged")
    }

    private var actions: some View {
        actionButton.accessibilityIdentifier("habit-action-\(habit.id)")
    }

    @ViewBuilder private var actionButton: some View {
        switch habit.kind {
        case .avoid:
            Button(level == .full ? "Clean ✓" : "Clean today") { store.log(.full, habitID: habit.id) }
                .buttonStyle(.bordered).tint(Theme.jade).disabled(level == .full)
        case .timer:
            Button { onTimer() } label: { Label(minutesLabel, systemImage: "play.fill") }
                .buttonStyle(.borderedProminent).tint(Theme.ink)
        case .sleep:
            Button(level == nil ? "Log sleep" : "Edit") { onSleep() }.buttonStyle(.bordered)
        case .focus:
            Text(minutesLabel).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        case .build, .checklist:
            Button(level == .full ? "Done ✓" : "Done") { store.log(.full, habitID: habit.id) }
                .buttonStyle(.borderedProminent).tint(Theme.jade).disabled(level == .full)
        }
    }

    /// Today's full price: weak habits pay more (strength), per-habit streak bonus included.
    private var price: Int {
        let streak = store.habitStreak(habit.id)
        return RewardRules.habitReward(difficulty: habit.difficulty, level: .full,
                                       strengthValue: store.strength[habit.id] ?? 0, habitStreakDays: streak).grit
    }

    private var minutesLabel: String {
        let done = completion?.minutes ?? 0, target = habit.targetMinutes ?? 0
        // Past the goal, "75/25 min" reads like an error.
        return done > target ? "\(done) min (goal \(target))" : "\(done)/\(target) min"
    }

    private var checklist: some View {
        let ticked = Set(completion?.stepsDone ?? store.draftSteps(habit.id))
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(habit.steps.enumerated()), id: \.element) { i, step in
                Button { store.toggleStep(step, habit: habit) } label: {
                    Label(step, systemImage: ticked.contains(step) ? "checkmark.square.fill" : "square")
                        .foregroundStyle(ticked.contains(step) ? Theme.jade : .primary)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("habit-step-\(habit.id)-\(i)")
            }
        }
        .font(.subheadline)
    }
}

/// Seven dots, oldest left: green full, gold min, red slip, grey nothing.
struct WeekStrip: View {
    let entries: [Completion?]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(entries.indices, id: \.self) { i in
                Circle().fill(color(entries[i]?.level)).frame(width: 8, height: 8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entries.filter { $0?.level.countsAsDone == true }.count) of last 7 days done")
    }

    private func color(_ level: CompletionLevel?) -> Color {
        switch level {
        case .full: return Theme.jade
        case .minimum: return Theme.gold
        case .slipped: return Theme.accent
        default: return .gray.opacity(0.3)
        }
    }
}

/// Wilted (red, pays more) / healthy / blooming (blue, pays less): Habitica-style strength, our colours.
struct TierBadge: View {
    let tier: HabitTier
    let multiplier: Double

    var body: some View {
        let (symbol, color, label): (String, Color, String) = switch tier {
        case .wilted: ("leaf.arrow.triangle.circlepath", Theme.accent, "Wilting")
        case .healthy: ("leaf.fill", Theme.jade, "Healthy")
        case .blooming: ("camera.macro", .blue, "Blooming")
        }
        Label(String(format: "×%.1f", multiplier), systemImage: symbol)
            .font(.caption2.weight(.bold).monospacedDigit())
            .foregroundStyle(color)
            .accessibilityLabel("\(label) habit, pays \(String(format: "%.1f", multiplier)) times")
    }
}

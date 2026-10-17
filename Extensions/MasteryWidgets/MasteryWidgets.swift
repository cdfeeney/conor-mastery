import SwiftUI
import WidgetKit

/// Reads the app's snapshot; refreshes at midnight so a new day shows as "nothing done yet".
struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry { SnapshotEntry(date: .now, snapshot: .placeholder) }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(entry(at: .now, preview: context.isPreview))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let now = Date.now
        let calendar = Calendar.current
        // Calendar arithmetic, not +86,400 s, so DST days still roll over at the next midnight.
        let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
            ?? now.addingTimeInterval(86_400)
        completion(Timeline(entries: [entry(at: now, preview: false), entry(at: midnight, preview: false)],
                            policy: .after(midnight)))
    }

    private func entry(at date: Date, preview: Bool) -> SnapshotEntry {
        let stored = WidgetSnapshot.load() ?? (preview ? .placeholder : nil)
        return SnapshotEntry(date: date, snapshot: stored?.asOf(WidgetSnapshot.dayString(date)))
    }
}

struct SnapshotEntry: TimelineEntry {
    let date: Date
    /// Nil until the app has run once.
    let snapshot: WidgetSnapshot?
}

// MARK: - Home screen

struct TodayWidgetView: View {
    let entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let s = entry.snapshot, s.isNewDay {
                newDay(s)
            } else if let s = entry.snapshot {
                switch family {
                case .systemMedium: medium(s)
                case .accessoryCircular: circular(s)
                case .accessoryRectangular: rectangular(s)
                case .accessoryInline: Label("\(s.done)/\(s.required) · \(s.streak)-day streak", systemImage: "flame.fill")
                default: small(s)
                }
            } else {
                Text("Open Mastery once to set up your widget.").font(.caption)
            }
        }
        .widgetURL(URL(string: "conormastery://today"))
        .containerBackground(for: .widget) { WidgetTheme.background }
    }

    /// A new day before the app has opened: streak still standing, prompt to start.
    @ViewBuilder private func newDay(_ s: WidgetSnapshot) -> some View {
        switch family {
        case .accessoryInline: Label("\(s.streak)-day streak · new day", systemImage: "flame.fill")
        case .accessoryCircular: Image(systemName: "sunrise.fill").font(.title2)
        default:
            VStack(alignment: .leading, spacing: 4) {
                StreakLabel(streak: s.streak)
                Text("New day").font(.headline)
                Text("Open Mastery to start.").font(.caption)
            }
            .foregroundStyle(family == .accessoryRectangular ? .primary : Color.white)
        }
    }

    private func small(_ s: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .bottom) {
                Image("hero-\(s.belt)").resizable().interpolation(.none).frame(width: 32, height: 32)
                Spacer()
                StreakLabel(streak: s.streak)
            }
            Spacer(minLength: 0)
            Text("\(s.done)/\(s.required)").font(.system(size: 30, weight: .heavy, design: .rounded)).monospacedDigit()
            ProgressView(value: Double(s.done), total: Double(max(s.required, 1))).tint(WidgetTheme.jade)
            Text(s.nextOpen.map { "Next: \($0)" } ?? "All done today").font(.caption2).lineLimit(1)
        }
        .foregroundStyle(.white)
    }

    private func medium(_ s: WidgetSnapshot) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Image("hero-\(s.belt)").resizable().interpolation(.none).frame(width: 40, height: 40)
                StreakLabel(streak: s.streak)
                Text("\(s.done)/\(s.required) done").font(.headline).monospacedDigit()
                Label("\(s.grit)", systemImage: "seal.fill").font(.caption).foregroundStyle(WidgetTheme.gold)
            }
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(s.items.prefix(6).enumerated()), id: \.offset) { _, item in
                    Label(item.title, systemImage: item.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.caption).lineLimit(1)
                        .foregroundStyle(item.isDone ? WidgetTheme.jade : .white)
                }
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
    }

    // MARK: Lock screen

    private func circular(_ s: WidgetSnapshot) -> some View {
        Gauge(value: Double(s.done), in: 0...Double(max(s.required, 1))) {
            Image(systemName: "flame.fill")
        } currentValueLabel: {
            Text("\(s.done)")
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }

    private func rectangular(_ s: WidgetSnapshot) -> some View {
        VStack(alignment: .leading) {
            Label("\(s.streak)-day streak", systemImage: "flame.fill").font(.headline)
            Text("\(s.done) of \(s.required) done")
            Text(s.nextOpen.map { "Next: \($0)" } ?? "All done today").lineLimit(1)
        }
    }
}

struct StreakLabel: View {
    let streak: Int
    var body: some View {
        Label("\(streak)", systemImage: "flame.fill").font(.subheadline.weight(.bold)).foregroundStyle(WidgetTheme.accent)
    }
}

enum WidgetTheme {
    static let background = Color(red: 0.11, green: 0.14, blue: 0.25)   // the app's night
    static let accent = Color(red: 0.89, green: 0.34, blue: 0.18)
    static let gold = Color(red: 0.95, green: 0.69, blue: 0.20)
    static let jade = Color(red: 0.17, green: 0.66, blue: 0.29)
}

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MasteryToday", provider: SnapshotProvider()) { TodayWidgetView(entry: $0) }
            .configurationDisplayName("Today")
            .description("Your streak, today's habits and what's next.")
            .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct MasteryWidgetBundle: WidgetBundle {
    var body: some Widget { TodayWidget() }
}

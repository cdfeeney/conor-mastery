import MasteryCore
import SwiftUI

/// GitHub-style history (owner 10-21): the Perfect Day grid, then one smaller grid per habit.
struct HistoryView: View {
    @Environment(MasteryStore.self) private var store
    /// 26 weeks at 9 pt fit a phone's width; the Perfect Day grid scrolls (13 pt squares).
    private static let weekCount = 26

    var body: some View {
        let streak = store.streak
        List {
            Section("Perfect Days") {
                HStack {
                    stat("\(streak.current)", "Current")
                    stat("\(streak.best)", "Best")
                    stat("\(streak.perfectDays)", "Perfect")
                    stat("\(streak.secondWinds)", "Second Winds")
                }
                let weeks = HabitHistory.weeks(endingOn: store.today, count: Self.weekCount, timeZone: store.timeZone)
                ScrollView(.horizontal, showsIndicators: false) {
                    ContributionGrid(weeks: weeks, cell: 13) { store.perfectDayMark(on: $0) }
                }
                .defaultScrollAnchor(.trailing)
                .accessibilityIdentifier("history-perfect-grid")
                // Gate run 21: "2 Perfect" with no green squares read as broken; a Min day is still a Perfect Day.
                HistoryLegend(items: [("Perfect", .full), ("Perfect with a Min", .minimum), ("Some", .partial),
                                      ("Saved", .saved), ("Missed", .missed)])
            }
            Section("Each habit · last \(Self.weekCount) weeks") {
                let weeks = HabitHistory.weeks(endingOn: store.today, count: Self.weekCount, timeZone: store.timeZone)
                ForEach(store.historyRows) { row in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(row.title).font(.subheadline.weight(.semibold))
                            Spacer()
                            let tally = ContributionGrid.tally(weeks) { store.historyMark(row.habits, on: $0) }
                            Text("\(tally.done) of \(tally.counted) days").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                        ContributionGrid(weeks: weeks, cell: 9) { store.historyMark(row.habits, on: $0) }
                    }
                    .padding(.vertical, 2)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("history-habit-\(row.id)")
                }
            }
        }
        .skyBackground()
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.weight(.bold).monospacedDigit())
            Text(label).font(.caption2).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

}

/// Week columns, Sunday on top; days after today are left empty.
struct ContributionGrid: View {
    let weeks: [[DayKey?]]
    let cell: CGFloat
    let mark: (DayKey) -> HistoryMark

    var body: some View {
        let spacing = cell * 0.25
        let marks = weeks.map { $0.map { $0.map(mark) } }
        let tally = Self.tally(marks)
        HStack(alignment: .top, spacing: spacing) {
            ForEach(marks.indices, id: \.self) { w in
                VStack(spacing: spacing) {
                    ForEach(0..<7, id: \.self) { d in
                        RoundedRectangle(cornerRadius: cell * 0.2)
                            .fill(Self.color(marks[w][d]))
                            .overlay {
                                if marks[w][d] == .open {
                                    RoundedRectangle(cornerRadius: cell * 0.2).stroke(Theme.navy, lineWidth: 1)
                                }
                            }
                            .frame(width: cell, height: cell)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(tally.done) of \(tally.counted) days done")
    }

    /// Days done (full or Min) out of days that counted (not before start, in the future, or off).
    static func tally(_ weeks: [[DayKey?]], mark: (DayKey) -> HistoryMark) -> (done: Int, counted: Int) {
        tally(weeks.map { $0.map { $0.map(mark) } })
    }

    private static func tally(_ marks: [[HistoryMark?]]) -> (done: Int, counted: Int) {
        let counted = marks.joined().compactMap { $0 }.filter { ![.beforeStart, .future, .off].contains($0) }
        return (counted.filter { $0 == .full || $0 == .minimum }.count, counted.count)
    }

    static func color(_ mark: HistoryMark?) -> Color {
        switch mark {
        case .full: Theme.jade
        case .minimum: Theme.gold
        case .partial: Theme.jade.opacity(0.4)
        case .saved: Color.blue.opacity(0.5)
        case .missed: Theme.accent.opacity(0.45)
        case .slipped: Theme.accent
        case .open, .off: Color.gray.opacity(0.18)
        case .beforeStart: Color.gray.opacity(0.07)
        case .future, nil: .clear
        }
    }
}

struct HistoryLegend: View {
    let items: [(String, HistoryMark)]

    var body: some View {
        // Wraps onto two lines on a narrow phone rather than squeezing.
        ViewThatFits {
            row(items)
            VStack(alignment: .leading, spacing: 6) {
                row(Array(items.prefix(2)))
                row(Array(items.dropFirst(2)))
            }
        }
        .accessibilityHidden(true)
    }

    private func row(_ items: [(String, HistoryMark)]) -> some View {
        HStack(spacing: 10) {
            ForEach(items, id: \.0) { item in
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2).fill(ContributionGrid.color(item.1)).frame(width: 10, height: 10)
                    Text(item.0).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }
}

import MasteryCore
import SwiftUI

/// Today's coach lesson: one tip, a link to the moment in the source, and tonight's "did you do it?".
struct LessonCard: View {
    @Environment(MasteryStore.self) private var store

    var body: some View {
        if let lesson = store.lesson {
            VStack(alignment: .leading, spacing: 10) {
                Text(store.state.habit(lesson.habitID)?.title.uppercased() ?? lesson.habitID)
                    .font(.caption.weight(.bold)).foregroundStyle(Theme.accent)
                Text(lesson.text).font(.body.weight(.semibold))
                LessonSourceLink(lesson: lesson)
                answerRow
                PinButton(lessonID: lesson.id)
            }
            .padding(.vertical, 4)
        } else {
            Text("You've kept every lesson. The tip library is still in the Coach tab.")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var answerRow: some View {
        if let answer = store.lessonAnswer {
            Label(answer.status == .kept ? "Kept: +\(RewardRules.lessonGrit) grit" : "Not yet: it comes back in \(LessonPlanner.reviewAfterDays) days",
                  systemImage: answer.status == .kept ? "checkmark.seal.fill" : "arrow.clockwise")
                .font(.subheadline).foregroundStyle(answer.status == .kept ? Theme.jade : .secondary)
        } else {
            HStack {
                Button("I did it  +\(RewardRules.lessonGrit)") { store.answerLesson(kept: true) }
                    .buttonStyle(.borderedProminent).tint(Theme.ink)
                    .accessibilityIdentifier("lesson-kept")
                Button("Not today") { store.answerLesson(kept: false) }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("lesson-not-today")
            }
        }
    }
}

struct LessonSourceLink: View {
    let lesson: Lesson

    var body: some View {
        if let url = lesson.videoURL {
            Link(destination: url) { Label("Watch it (\(lesson.locator))", systemImage: "play.rectangle") }
                .font(.caption)
        } else {
            Label("\(SourceName.readable(lesson.source)) · \(lesson.locator)", systemImage: "book").font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// Citation keys are for the KB, not for people: "res:lally2010" reads "Lally 2010", "book:franklin-autobiography"
/// reads "Franklin Autobiography", "yt:<id> @ 06:38" reads "video at 06:38" (gate run 39158232302).
enum SourceName {
    static func readable(_ key: String) -> String {
        if key.hasPrefix("yt:") { return "Video" }
        if key.hasPrefix("book:") {
            return key.dropFirst(5).split(separator: "-").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
        }
        guard key.hasPrefix("res:") else { return key }
        let body = key.dropFirst(4)
        guard let split = body.firstIndex(where: \.isNumber) else { return String(body).capitalized }
        return "\(body[..<split].capitalized) \(body[split...])"
    }

    /// Prose that carries citation keys, as the coach notes do.
    static func prose(_ text: String) -> String {
        text.replacing(#/yt:[A-Za-z0-9_-]+ @ /#, with: "video at ")
            .replacing(#/(?:res|book):[a-z0-9-]+/#) { readable(String($0.output)) }
    }
}

/// "Make it a rule": pinned lessons show on the habit page and in tonight's check.
struct PinButton: View {
    let lessonID: String
    @Environment(MasteryStore.self) private var store

    var body: some View {
        let pinned = store.settings.pinnedRules.contains(lessonID)
        Button { store.togglePinned(lessonID) } label: {
            Label(pinned ? "One of your rules" : "Make it a rule", systemImage: pinned ? "pin.fill" : "pin")
        }
        .font(.caption).buttonStyle(.borderless)
    }
}

/// Every lesson, grouped by habit, with where you are on each.
struct TipLibraryView: View {
    @Environment(MasteryStore.self) private var store
    @State private var query = ""

    var body: some View {
        List {
            ForEach(store.habits) { habit in
                let lessons = matching(store.plan.lessons.filter { $0.habitID == habit.id })
                if !lessons.isEmpty {
                    Section("\(habit.title) · \(lessons.count)") {
                        ForEach(lessons) { lesson in row(lesson) }
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "Search tips")
        .navigationTitle("Tip library")
    }

    private func matching(_ lessons: [Lesson]) -> [Lesson] {
        let q = query.trimmingCharacters(in: .whitespaces)
        return q.isEmpty ? lessons : lessons.filter { $0.text.localizedCaseInsensitiveContains(q) }
    }

    private func row(_ lesson: Lesson) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text(lesson.text)
                Spacer()
                status(store.settings.lessons[lesson.id])
            }
            HStack(spacing: 16) {
                LessonSourceLink(lesson: lesson)
                PinButton(lessonID: lesson.id)
            }
        }
        .padding(.vertical, 2)
    }

    private func status(_ record: LessonRecord?) -> some View {
        let (text, color): (String, Color) = switch record?.status {
        case .kept: ("Kept", Theme.jade)
        case .learning: ("Learning", Theme.gold)
        case nil: ("New", .secondary)
        }
        return Text(text).font(.caption2.weight(.bold)).foregroundStyle(color)
    }
}

/// Your pinned rules, optionally for one habit.
struct RulesList: View {
    var habitID: String?
    @Environment(MasteryStore.self) private var store

    var body: some View {
        ForEach(store.pinnedLessons.filter { habitID == nil || $0.habitID == habitID }) { lesson in
            Label(lesson.text, systemImage: "pin.fill")
                .swipeActions { Button("Unpin") { store.togglePinned(lesson.id) } }
        }
    }
}

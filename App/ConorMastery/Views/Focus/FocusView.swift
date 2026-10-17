import MasteryCore
import SwiftUI

/// Pomodoro-style focus (25/5 default). Locked-In shields distraction apps, pays 1.5x, and costs
/// grit if stopped early (Monke's hardcore mode, adapted).
/// A running session, persisted whole so a session survives iOS closing the app and credits the
/// day (and habit) it started on.
struct ActiveFocus: Codable, Equatable {
    static let storageKey = "focus.active.v1"

    /// The running session saved by FocusView, if any.
    static func load() -> ActiveFocus? {
        UserDefaults.standard.data(forKey: storageKey).flatMap { try? JSONDecoder().decode(ActiveFocus.self, from: $0) }
    }

    let startedAt: Date
    let day: DayKey
    let plannedMinutes: Int
    let lockedIn: Bool
    let note: String?
    let habitID: String?
}

struct FocusView: View {
    @Environment(MasteryStore.self) private var store
    @Environment(ScreenTimeService.self) private var screenTime
    @AppStorage(ActiveFocus.storageKey) private var activeData = Data()
    @State private var plannedMinutes = 25
    @State private var lockedIn = false
    @State private var countsForReset = true
    @State private var note = ""
    @State private var confirmStop = false

    private var active: ActiveFocus? { try? JSONDecoder().decode(ActiveFocus.self, from: activeData) }

    var body: some View {
        NavigationStack {
            Group {
                if let active { running(active) } else { setup }
            }
            .navigationTitle("Focus")
        }
    }

    private var setup: some View {
        Form {
            Section {
                Stepper("\(plannedMinutes) minutes", value: $plannedMinutes, in: 5...180, step: 5)
                Toggle(isOn: $lockedIn) {
                    VStack(alignment: .leading) {
                        Text("Locked in")
                        Text("Blocks your apps. 1.5x grit. Stopping early costs \(RewardRules.lockedInEarlyStopPenalty).")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .disabled(!screenTime.canEnforce)
                if !screenTime.canEnforce {
                    Text("Set up Screen Time in Settings to use Locked in.").font(.caption).foregroundStyle(.secondary)
                }
                if store.state.habit("reset-focus") != nil { Toggle("Counts for Reset focus", isOn: $countsForReset) }
                TextField("What are you working on?", text: $note)
            }
            Section {
                Button { start() } label: { Label("Start", systemImage: "play.fill").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent).tint(Theme.accent).controlSize(.large)
            }
            Section("Today") {
                LabeledContent("Focused", value: "\(store.focusMinutesToday) min")
                LabeledContent("Level", value: "\(store.level.level) · \(store.level.belt.title)")
            }
        }
    }

    private func running(_ session: ActiveFocus) -> some View {
        ZStack {
            Theme.night.ignoresSafeArea()
            VStack(spacing: 24) {
                Text(session.lockedIn ? "Locked in." : "Focusing.").font(.title3).foregroundStyle(.white.opacity(0.8))
                HStack(alignment: .bottom, spacing: 4) {
                    PixelSprite(ItemArt.hero(store.level.belt), scale: 5)
                    PixelSprite("fire-pit", scale: 4)
                }
                .accessibilityHidden(true)
                TimelineView(.periodic(from: session.startedAt, by: 1)) { context in
                    let elapsed = context.date.timeIntervalSince(session.startedAt)
                    let left = max(Double(session.plannedMinutes * 60) - elapsed, 0)
                    Text(String(format: "%02d:%02d", Int(left) / 60, Int(left) % 60))
                        .font(.system(size: 72, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                        .onChange(of: left == 0, initial: true) { _, done in if done { finish(stoppedEarly: false) } }
                }
                if let note = session.note { Text(note).foregroundStyle(.white.opacity(0.7)) }
                Button("STOP") { if session.lockedIn { confirmStop = true } else { finish(stoppedEarly: true) } }
                    .font(.title2.weight(.heavy)).buttonStyle(.borderedProminent).tint(Theme.accent)
            }
        }
        .confirmationDialog("Stop early?", isPresented: $confirmStop, titleVisibility: .visible) {
            Button("Stop and lose \(RewardRules.lockedInEarlyStopPenalty) grit", role: .destructive) { finish(stoppedEarly: true) }
            Button("Keep going", role: .cancel) {}
        } message: {
            Text("Locked-in sessions pay 1.5x only when finished.")
        }
    }

    private func start() {
        let useLock = lockedIn && screenTime.canEnforce
        let session = ActiveFocus(
            startedAt: .now, day: store.today, plannedMinutes: plannedMinutes, lockedIn: useLock,
            note: note.isEmpty ? nil : note,
            habitID: countsForReset && store.state.habit("reset-focus") != nil ? "reset-focus" : nil)
        activeData = (try? JSONEncoder().encode(session)) ?? Data()
        if useLock { screenTime.startLockedIn(minutes: plannedMinutes, store: store) }
        FocusLiveActivity.start(session, belt: store.level.belt.rawValue)
    }

    private func finish(stoppedEarly: Bool) {
        guard let session = active else { return }
        activeData = Data() // clear first so a re-render can't finish twice
        let elapsed = min(Int(Date.now.timeIntervalSince(session.startedAt) / 60), session.plannedMinutes)
        store.record(focus: FocusSession(day: session.day, plannedMinutes: session.plannedMinutes,
                                         focusedMinutes: stoppedEarly ? elapsed : session.plannedMinutes,
                                         lockedIn: session.lockedIn, note: session.note, habitID: session.habitID))
        if session.lockedIn { screenTime.endLockedIn(store: store) }
        FocusLiveActivity.endAll()
        note = ""
    }
}

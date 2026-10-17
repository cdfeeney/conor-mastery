import MasteryCore
import SwiftData
import SwiftUI

enum AppTab: Hashable { case dojo, today, focus, sleep, coach }

struct RootView: View {
    @State private var store: MasteryStore
    @State private var screenTime = ScreenTimeService()
    private let notifications = NotificationService()
    @State private var tab: AppTab = .dojo
    @AppStorage("onboarding.yourDay.seen.v1") private var hasSeenYourDay = false
    @Environment(\.scenePhase) private var scenePhase

    init(context: ModelContext) {
        _store = State(initialValue: MasteryStore(context: context))
    }

    var body: some View {
        TabView(selection: $tab) {
            Tab("Dojo", systemImage: "mountain.2.fill", value: .dojo) { DojoView(tab: $tab) }
            Tab("Today", systemImage: "checklist", value: .today) { TodayView() }
            Tab("Focus", systemImage: "scope", value: .focus) { FocusView() }
            Tab("Sleep", systemImage: "moon.zzz.fill", value: .sleep) { SleepView() }
            Tab("Coach", systemImage: "book.closed.fill", value: .coach) { CoachView() }
        }
        .tint(Theme.accent)
        .environment(store)
        .environment(screenTime)
        .overlay(alignment: .top) { RewardToastView() .environment(store) }
        .sheet(isPresented: Binding(get: { !hasSeenYourDay && !store.habits.isEmpty }, set: { if !$0 { hasSeenYourDay = true } })) {
            YourDayView().environment(store)
        }
        .alert("Heads up", isPresented: errorBinding) {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
        .onAppear {
            if let problem = StartupProblem.message { store.errorMessage = problem }
            refresh()
        }
        .onChange(of: scenePhase) { _, phase in if phase == .active { refresh() } }
        // Any habit change can open or close the morning gate.
        .onChange(of: store.state.completions.count) { _, _ in
            WidgetPublisher.publish(store)
            screenTime.apply(store: store)
            Task { await notifications.reschedule(store.reminders()) }
        }
        .onChange(of: store.settings) { _, _ in
            WidgetPublisher.publish(store)
            Task { await notifications.reschedule(store.reminders()) }
        }
        .onChange(of: store.grit) { _, _ in WidgetPublisher.publish(store) }
        // Widgets open the app on Today.
        .onOpenURL { url in
            switch url.host {
            case "today": tab = .today
            case "focus": tab = .focus
            default: break
            }
        }
        // Juice: a sound and a tap on every reward (sound follows the Settings toggle), a jingle on level-up.
        .onChange(of: store.lastReward?.id) { _, id in
            guard id != nil, let toast = store.lastReward, toast.reward.grit > 0 || toast.drop != nil else { return }
            if store.settings.soundOn { SoundPlayer.play(toast.drop == nil ? .coin : .powerup) }
        }
        .onChange(of: store.level.level) { old, new in
            if new > old, store.settings.soundOn { SoundPlayer.play(.levelup) }
        }
        .sensoryFeedback(.success, trigger: store.lastReward?.id) { _, new in
            new != nil && ((store.lastReward?.reward.grit ?? 0) > 0 || store.lastReward?.drop != nil)
        }
        .task { if await notifications.requestAuthorization() { await notifications.reschedule(store.reminders()) } }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })
    }

    private func refresh() {
        store.reload()
        store.syncCoach()
        WidgetPublisher.publish(store)
        FocusLiveActivity.reconcile(active: ActiveFocus.load())
        screenTime.apply(store: store)
        Task { await notifications.reschedule(store.reminders()) }
    }
}

struct RewardToastView: View {
    @Environment(MasteryStore.self) private var store

    var body: some View {
        if let toast = store.lastReward {
            HStack(spacing: 10) {
                Text(toast.title).font(.subheadline.weight(.semibold))
                if toast.reward.grit != 0 { Label("\(toast.reward.grit > 0 ? "+" : "")\(toast.reward.grit)", systemImage: "flame.fill") }
                if toast.reward.xp > 0 { Text("+\(toast.reward.xp) XP").foregroundStyle(Theme.gold) }
                if let drop = toast.drop {
                    Label(drop.kind == .koiEgg ? "Koi egg!" : "Seed: \(Catalog.item(drop.itemID)?.name ?? drop.itemID)",
                          systemImage: drop.kind == .koiEgg ? "fish.fill" : "leaf.fill")
                        .foregroundStyle(Theme.jade)
                }
            }
            .font(.subheadline.monospacedDigit())
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
            .task(id: toast.id) {
                try? await Task.sleep(for: .seconds(2))
                withAnimation { store.lastReward = nil }
            }
            .accessibilityElement(children: .combine)
        }
    }
}

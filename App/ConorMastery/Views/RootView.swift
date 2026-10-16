import SwiftData
import SwiftUI

enum AppTab: Hashable { case dojo, today, focus, sleep, coach }

struct RootView: View {
    @State private var store: MasteryStore
    @State private var screenTime = ScreenTimeService()
    @State private var tab: AppTab = .dojo
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
        .onChange(of: store.state.completions.count) { _, _ in screenTime.apply(store: store) }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })
    }

    private func refresh() {
        store.reload()
        store.syncCoach()
        screenTime.apply(store: store)
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

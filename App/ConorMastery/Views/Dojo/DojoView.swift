import MasteryCore
import SwiftUI

/// Home: the garden world, HUD, today's progress, daily challenge, CHECK-IN / FOCUS.
struct DojoView: View {
    @Binding var tab: AppTab
    @Environment(MasteryStore.self) private var store
    @State private var showShop = false
    @State private var showSettings = false
    @State private var building = false
    @State private var selectedItem: String?

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.night, Theme.night.opacity(0.75)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            WorldView(building: building, selectedItem: $selectedItem)
            VStack(spacing: 10) {
                topBar
                if !building {
                    ProgressCard()
                    if let challenge = store.challenge { ChallengeCard(challenge: challenge) }
                }
                Spacer()
                if building { BuildPalette(selectedItem: $selectedItem) }
                bottomBar
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .sheet(isPresented: $showShop) { ShopSheet() }
        .sheet(isPresented: $showSettings) { SettingsView() }
    }

    private var topBar: some View {
        HStack {
            HUDPill()
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill").font(.title2).foregroundStyle(.white)
            }
            .accessibilityLabel("Settings")
        }
        .padding(.top, 4)
    }

    private var bottomBar: some View {
        HStack(alignment: .bottom) {
            circleButton(building ? "checkmark" : "pencil", label: building ? "Done building" : "Build") {
                building.toggle()
                selectedItem = nil
            }
            Spacer()
            VStack(spacing: 10) {
                GameButton(title: "CHECK-IN", color: Theme.accent) { tab = .today }
                GameButton(title: "FOCUS", color: Color(red: 0.36, green: 0.75, blue: 0.95)) { tab = .focus }
            }
            Spacer()
            circleButton("cart.fill", label: "Shop") { showShop = true }
        }
    }

    private func circleButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.title2.weight(.semibold)).foregroundStyle(Theme.ink)
                .frame(width: 56, height: 56)
                .background(Theme.paper, in: Circle())
                .overlay(Circle().stroke(Theme.ink, lineWidth: 3))
        }
        .accessibilityLabel(label)
    }
}

struct ProgressCard: View {
    @Environment(MasteryStore.self) private var store

    var body: some View {
        HStack {
            stat("\(store.doneTodayCount)/\(store.requiredToday.count)", "habits", "checkmark.circle.fill")
            Spacer()
            stat("\(store.focusMinutesToday)m", "focused", "timer")
            Spacer()
            stat("+\(store.gritEarnedToday)", "grit", "seal.fill")
        }
        .padding(14)
        .background(Theme.ink.opacity(0.85), in: RoundedRectangle(cornerRadius: 16))
        .foregroundStyle(.white)
    }

    private func stat(_ value: String, _ caption: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(value, systemImage: symbol).font(.headline.monospacedDigit())
            Text(caption).font(.caption).foregroundStyle(.white.opacity(0.7))
        }
        .accessibilityElement(children: .combine)
    }
}

struct ChallengeCard: View {
    let challenge: DailyChallenge
    @Environment(MasteryStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Daily challenge").font(.caption.weight(.bold)).foregroundStyle(Theme.gold)
                Spacer()
                Text(timeLeft).font(.caption.monospacedDigit()).foregroundStyle(.white.opacity(0.7))
            }
            Text(challenge.text).font(.subheadline.weight(.semibold))
            HStack {
                Label("+\(challenge.reward)", systemImage: "seal.fill").foregroundStyle(Theme.gold)
                Spacer()
                Button(store.challengeDone ? "Done" : "Mark complete") { store.completeChallenge() }
                    .buttonStyle(.borderedProminent).tint(Theme.jade)
                    .disabled(store.challengeDone)
            }
        }
        .padding(14)
        .foregroundStyle(.white)
        .background(Theme.ink.opacity(0.85), in: RoundedRectangle(cornerRadius: 16))
    }

    private var timeLeft: String {
        let end = Calendar.current.startOfDay(for: .now).addingTimeInterval(86_400)
        let minutes = Int(end.timeIntervalSinceNow / 60)
        return "\(minutes / 60)h \(minutes % 60)m left"
    }
}

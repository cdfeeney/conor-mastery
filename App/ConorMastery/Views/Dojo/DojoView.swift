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
            if building {
                Theme.water.ignoresSafeArea()
            } else {
                WorldView(building: false, selectedItem: $selectedItem)
                    // Low energy greys the garden out; a Perfect Day or level-up brings colour back.
                    .saturation(1 - store.energy.greyness * 0.85)
            }
            VStack(spacing: 10) {
                topBar
                if building {
                    // Its own space between the bar and the tray: as a backdrop the tray covered the bottom row and
                    // the tiles were hard to hit (owner 10-18).
                    WorldView(building: true, selectedItem: $selectedItem)
                        .frame(maxHeight: .infinity)
                } else {
                    EnergyBar(energy: store.energy, isRestDay: store.isRestDay)
                    ProgressCard()
                    if let challenge = store.challenge { ChallengeCard(challenge: challenge) }
                    Spacer()
                }
                if building { BuildPalette(selectedItem: $selectedItem) } else { HabitPlantsRow(tab: $tab) }
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
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Settings")
            .accessibilityIdentifier("dojo-settings")
        }
        .padding(.top, 4)
    }

    private var bottomBar: some View {
        HStack(alignment: .bottom) {
            circleButton(building ? "checkmark" : "pencil", label: building ? "Done building" : "Build") {
                building.toggle()
                selectedItem = nil
            }
            .accessibilityIdentifier("dojo-build")
            Spacer()
            VStack(spacing: 10) {
                GameButton(title: "CHECK-IN", color: Theme.accent) { tab = .today }
                    .accessibilityIdentifier("dojo-checkin")
                GameButton(title: "FOCUS", color: Color(red: 0.36, green: 0.75, blue: 0.95)) { tab = .focus }
                    .accessibilityIdentifier("dojo-focus")
            }
            Spacer()
            circleButton("cart.fill", label: "Shop") { showShop = true }
                .accessibilityIdentifier("dojo-shop")
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                stat("\(store.doneTodayCount)/\(store.requiredToday.count)", "habits", "checkmark.circle.fill")
                Spacer()
                stat("\(store.focusMinutesToday)m", "focused", "timer")
                Spacer()
                stat("+\(store.gritEarnedToday)", "grit", "seal.fill")
            }
            // Where today's grit came from: the total alone matched nothing on screen.
            let sources = store.state.ledger.earnedBySource(on: store.today)
            if !sources.isEmpty {
                Text(sources.map { "\($0.source.rawValue.capitalized) +\($0.grit)" }.joined(separator: " · "))
                    .font(.caption.monospacedDigit()).foregroundStyle(.white.opacity(0.7))
            }
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
        // Ticks each minute so the countdown and the 5 PM opening update while the Dojo stays open.
        TimelineView(.everyMinute) { context in card(now: context.date) }
    }

    private func card(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Daily challenge").font(.caption.weight(.bold)).foregroundStyle(Theme.gold)
                Spacer()
                Text(timeLeft(now)).font(.caption.monospacedDigit()).foregroundStyle(.white.opacity(0.7))
            }
            Text(challenge.text).font(.subheadline.weight(.semibold))
            HStack {
                Label("+\(challenge.reward)", systemImage: "seal.fill").foregroundStyle(Theme.gold)
                Spacer()
                Button(buttonTitle(now)) { store.completeChallenge() }
                    .buttonStyle(.borderedProminent).tint(Theme.jade)
                    .disabled(store.challengeDone || isTooEarly(now))
                    .accessibilityIdentifier("challenge-complete")
            }
        }
        .padding(14)
        .foregroundStyle(.white)
        .background(Theme.ink.opacity(0.85), in: RoundedRectangle(cornerRadius: 16))
    }

    /// Gate run 21: a "tonight" challenge could be marked complete at 8 AM, before it could have been done.
    private func isTooEarly(_ now: Date) -> Bool {
        challenge.text.localizedCaseInsensitiveContains("tonight")
            && Calendar.current.component(.hour, from: now) < Self.eveningHour
    }
    private static let eveningHour = 17

    private func buttonTitle(_ now: Date) -> String {
        if store.challengeDone { return "Done" }
        return isTooEarly(now) ? "Opens at 5 PM" : "Mark complete"
    }

    private func timeLeft(_ now: Date) -> String {
        let end = Calendar.current.startOfDay(for: now).addingTimeInterval(86_400)
        let minutes = Int(end.timeIntervalSince(now) / 60)
        return "\(minutes / 60)h \(minutes % 60)m left"
    }
}

struct EnergyBar: View {
    let energy: EnergyState
    let isRestDay: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isRestDay ? "bed.double.fill" : "bolt.fill").foregroundStyle(Theme.gold)
            ProgressView(value: Double(energy.value), total: Double(EnergyRules.max))
                .tint(energy.value > 50 ? Theme.jade : Theme.accent)
            Text(isRestDay ? "Rest day" : "\(energy.value)").font(.caption.monospacedDigit()).foregroundStyle(.white)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(Theme.ink.opacity(0.85), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isRestDay ? "Rest day" : "Energy \(energy.value) of \(EnergyRules.max)")
    }
}

/// One plant per habit: a tuft when healthy, a sunflower when blooming, a grey drooping tuft when wilting.
/// Tap to go check in.
struct HabitPlantsRow: View {
    @Binding var tab: AppTab
    @Environment(MasteryStore.self) private var store

    var body: some View {
        Button { tab = .today } label: {
            HStack(spacing: 6) {
                ForEach(store.planHabits) { habit in plant(habit) }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Theme.ink.opacity(0.55), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Habit plants")
        .accessibilityHint("Opens Today")
    }

    private func plant(_ habit: HabitDefinition) -> some View {
        let tier = store.tier(habit.id)
        let isWilted = tier == .wilted
        return PixelSprite(tier == .blooming ? "sunflower" : "grass-tuft", scale: 2)
            .saturation(isWilted ? 0.15 : 1)
            .brightness(isWilted ? -0.15 : 0)
            .offset(y: isWilted ? 2 : 0)
            .accessibilityLabel("\(habit.title), \(isWilted ? "wilting" : tier == .blooming ? "blooming" : "healthy")")
    }
}

import MasteryCore
import SwiftUI

enum Theme {
    static let accent = Color(red: 0.89, green: 0.34, blue: 0.18)   // vermilion
    static let gold = Color(red: 0.95, green: 0.69, blue: 0.20)
    static let jade = Color(red: 0.17, green: 0.66, blue: 0.29)
    static let ink = Color(red: 0.09, green: 0.10, blue: 0.14)
    static let paper = Color(red: 0.98, green: 0.96, blue: 0.90)
    static let night = Color(red: 0.11, green: 0.14, blue: 0.25)
    static let grass = Color(red: 0.43, green: 0.62, blue: 0.36)
    static let grassDark = Color(red: 0.35, green: 0.53, blue: 0.30)

    static func color(_ belt: Belt) -> Color {
        switch belt {
        case .white: return .white
        case .yellow: return .yellow
        case .orange: return .orange
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        case .brown: return .brown
        case .black: return .black
        }
    }
}

/// HUD pill: belt + level bar | streak | grit (Monke's Lvl | fire | bananas pattern).
struct HUDPill: View {
    @Environment(MasteryStore.self) private var store

    var body: some View {
        let level = store.level
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Capsule().fill(Theme.color(level.belt)).frame(width: 18, height: 6)
                    .overlay(Capsule().stroke(.white.opacity(0.6), lineWidth: 0.5))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lvl \(level.level)").font(.caption.weight(.bold))
                    ProgressView(value: level.fraction).tint(Theme.jade).frame(width: 44)
                }
            }
            Divider().frame(height: 22)
            Label("\(store.streak.current)", systemImage: "flame.fill").foregroundStyle(Theme.accent)
            Divider().frame(height: 22)
            Label("\(store.grit)", systemImage: "seal.fill").foregroundStyle(Theme.gold)
        }
        .font(.subheadline.weight(.semibold).monospacedDigit())
        .foregroundStyle(.white)
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(Theme.ink.opacity(0.85), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Level \(level.level), \(level.belt.title). Streak \(store.streak.current) days. \(store.grit) grit.")
    }
}

/// Chunky game button (CHECK-IN / FOCUS).
struct GameButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.title3, design: .rounded).weight(.heavy))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 28).padding(.vertical, 12)
                .background(color, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.ink, lineWidth: 3))
                .shadow(color: Theme.ink.opacity(0.4), radius: 0, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

enum ItemArt {
    /// Placeholder art (emoji) until original illustrations exist. Never Monke assets.
    static func glyph(_ id: String) -> String {
        switch id {
        case "gravel": return "🪨"
        case "moss": return "🌿"
        case "path-stone": return "⚪️"
        case "boulder": return "🪨"
        case "bamboo": return "🎋"
        case "pine": return "🌲"
        case "bonsai": return "🪴"
        case "maple": return "🍁"
        case "cherry": return "🌸"
        case "lantern": return "🏮"
        case "fire-pit": return "🔥"
        case "pond": return "🐟"
        case "bridge": return "🌉"
        case "training-post": return "🥋"
        case "tent": return "⛺️"
        case "torii": return "⛩️"
        case "dojo": return "🏯"
        case "pagoda": return "🗼"
        default: return "❔"
        }
    }
}

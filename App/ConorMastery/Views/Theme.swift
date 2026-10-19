import MasteryCore
import SwiftUI
import UIKit

enum Theme {
    static let accent = Color(red: 0.89, green: 0.34, blue: 0.18)   // vermilion
    static let gold = Color(red: 0.95, green: 0.69, blue: 0.20)
    static let jade = Color(red: 0.17, green: 0.66, blue: 0.29)
    static let ink = Color(red: 0.09, green: 0.10, blue: 0.14)
    static let paper = Color(red: 0.98, green: 0.96, blue: 0.90)
    static let night = Color(red: 0.11, green: 0.14, blue: 0.25)
    static let water = Color(red: 0.36, green: 0.60, blue: 0.78)
    static let earth = Color(red: 0.55, green: 0.38, blue: 0.24)

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

extension View {
    /// The Dojo's light-blue sky behind every list and form, so all five tabs read as one game (owner 10-18: the
    /// other tabs looked like a different, black-and-orange app in dark mode).
    func skyBackground() -> some View {
        scrollContentBackground(.hidden).background(Theme.water.ignoresSafeArea())
    }

    /// At least 44 pt tall to tap: text links and checklist ticks were 14-18 pt (owner 10-18, tap-targets rule).
    func tapTarget() -> some View {
        frame(minHeight: 44, alignment: .leading).contentShape(Rectangle())
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

/// Pixel sprites from Assets.xcassets/Sprites, built by art/tools/build_sprites.py (Ninja Adventure, CC0;
/// the lantern and pagoda are drawn in-house). Never Monke assets.
enum ItemArt {
    /// Native pixel size, so sprites scale by whole numbers and stay crisp.
    static func pixelSize(_ id: String) -> CGSize {
        UIImage(named: id)?.size ?? CGSize(width: 16, height: 16)
    }

    static func hero(_ belt: Belt) -> String { "hero-\(belt.rawValue)" }
}

/// One sprite drawn nearest-neighbour at a whole-number scale.
struct PixelSprite: View {
    let id: String
    let scale: CGFloat

    init(_ id: String, scale: CGFloat) {
        self.id = id
        self.scale = scale
    }

    /// The largest whole-number scale that fits the sprite inside a `side` x `side` box.
    init(_ id: String, fitting side: CGFloat) {
        let size = ItemArt.pixelSize(id)
        self.init(id, scale: max(1, (side / max(size.width, size.height)).rounded(.down)))
    }

    var body: some View {
        let size = ItemArt.pixelSize(id)
        Image(id)
            .resizable()
            .interpolation(.none)
            .frame(width: size.width * scale, height: size.height * scale)
    }
}

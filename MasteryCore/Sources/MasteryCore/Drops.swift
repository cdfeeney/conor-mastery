import Foundation

/// Deterministic randomness: the same habit on the same day always rolls the same number, so undo/redo
/// can never re-roll a Focused Strike or a drop.
public enum StableRoll {
    /// FNV-1a 64-bit hash of `key`, mapped to [0, 1).
    public static func unit(_ key: String) -> Double {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        // splitmix64 finalizer: FNV alone leaves the high bits poorly mixed for near-identical keys.
        hash ^= hash >> 30
        hash = hash &* 0xbf58_476d_1ce4_e5b9
        hash ^= hash >> 27
        hash = hash &* 0x94d0_49bb_1331_11eb
        hash ^= hash >> 31
        return Double(hash >> 11) / Double(UInt64(1) << 53)
    }
}

public enum StrikeRules {
    /// Chance that a completion is a "Focused Strike" paying double grit.
    public static let chance = 0.04

    public static func isStrike(habitID: String, day: DayKey) -> Bool {
        StableRoll.unit("strike|\(habitID)|\(day.rawValue)") < chance
    }
}

public enum DropKind: String, Codable, Sendable {
    case seed, koiEgg
}

public struct Drop: Codable, Sendable, Hashable {
    public let kind: DropKind
    /// Catalog item the drop grows into (added to the garden inventory).
    public let itemID: String
}

/// Seeds and koi eggs from completions (Habitica's drops, re-themed). Weak habits drop more often.
public enum DropRules {
    public static let baseChance = 0.05
    public static let weakBonus = 0.10
    public static let koiShare = 0.2

    public static func chance(strengthValue: Double) -> Double {
        // 0 at max strength, 1 at min strength.
        let weakness = (StrengthRules.maxValue - StrengthRules.clamp(strengthValue))
            / (StrengthRules.maxValue - StrengthRules.minValue)
        return baseChance + weakBonus * weakness
    }

    /// Plants the player's level unlocks, cheapest first.
    static func seedPool(level: Int) -> [ShopItem] {
        Catalog.items.filter { $0.category == .plants && $0.minLevel <= level }.sorted { $0.price < $1.price }
    }

    public static func roll(habitID: String, day: DayKey, strengthValue: Double, level: Int) -> Drop? {
        guard StableRoll.unit("drop|\(habitID)|\(day.rawValue)") < chance(strengthValue: strengthValue) else { return nil }
        if StableRoll.unit("koi|\(habitID)|\(day.rawValue)") < koiShare, level >= (Catalog.item("pond")?.minLevel ?? 1) {
            return Drop(kind: .koiEgg, itemID: "pond")
        }
        let pool = seedPool(level: level)
        guard !pool.isEmpty else { return nil }
        let pick = Int(StableRoll.unit("seed|\(habitID)|\(day.rawValue)") * Double(pool.count))
        return Drop(kind: .seed, itemID: pool[Swift.min(pick, pool.count - 1)].id)
    }
}

/// A real-life reward the player prices in grit ("cheat meal = 150 grit").
public struct Treat: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let price: Int

    public init(id: String = UUID().uuidString, name: String, price: Int) {
        self.id = id
        self.name = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
        self.price = Swift.max(price, 1)
    }
}

/// Rest days (sick, travel): nothing is required, so streaks, strength and energy pause. Limited per month.
public enum RestRules {
    public static let perMonth = 3

    public static func canRest(on day: DayKey, restDays: Set<DayKey>) -> Bool {
        let month = day.rawValue.prefix(7)
        return restDays.contains(day) || restDays.filter { $0.rawValue.hasPrefix(month) }.count < perMonth
    }
}

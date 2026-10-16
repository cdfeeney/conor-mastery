import Foundation

public enum ItemCategory: String, Codable, Sendable, CaseIterable {
    case ground, plants, stone, light, water, buildings
}

public struct ShopItem: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let category: ItemCategory
    public let price: Int
    public let minLevel: Int

    public init(id: String, name: String, category: ItemCategory, price: Int, minLevel: Int = 1) {
        self.id = id; self.name = name; self.category = category; self.price = price; self.minLevel = minLevel
    }
}

/// Original Dojo Garden catalog (no Monke assets).
public enum Catalog {
    public static let items: [ShopItem] = [
        ShopItem(id: "gravel", name: "Raked Gravel", category: .ground, price: 10),
        ShopItem(id: "moss", name: "Moss Patch", category: .ground, price: 10),
        ShopItem(id: "path-stone", name: "Stepping Stone", category: .stone, price: 20),
        ShopItem(id: "boulder", name: "Boulder", category: .stone, price: 40),
        ShopItem(id: "bamboo", name: "Bamboo", category: .plants, price: 50),
        ShopItem(id: "pine", name: "Black Pine", category: .plants, price: 80),
        ShopItem(id: "bonsai", name: "Bonsai", category: .plants, price: 120, minLevel: 3),
        ShopItem(id: "maple", name: "Red Maple", category: .plants, price: 150, minLevel: 5),
        ShopItem(id: "cherry", name: "Cherry Blossom", category: .plants, price: 250, minLevel: 10),
        ShopItem(id: "lantern", name: "Stone Lantern", category: .light, price: 100),
        ShopItem(id: "fire-pit", name: "Fire Pit", category: .light, price: 60),
        ShopItem(id: "pond", name: "Koi Pond", category: .water, price: 300, minLevel: 5),
        ShopItem(id: "bridge", name: "Arched Bridge", category: .water, price: 350, minLevel: 10),
        ShopItem(id: "training-post", name: "Training Post", category: .buildings, price: 90),
        ShopItem(id: "tent", name: "Tent", category: .buildings, price: 120),
        ShopItem(id: "torii", name: "Torii Gate", category: .buildings, price: 500, minLevel: 15),
        ShopItem(id: "dojo", name: "Dojo", category: .buildings, price: 900, minLevel: 20),
        ShopItem(id: "pagoda", name: "Pagoda", category: .buildings, price: 1500, minLevel: 30)
    ]

    public static func item(_ id: String) -> ShopItem? { items.first { $0.id == id } }

    /// Land sizes and the grit to reach each one.
    public static let landExpansions: [(size: Int, price: Int)] = [(5, 150), (7, 400), (9, 900)]
}

public struct Placement: Codable, Sendable, Hashable {
    public let itemID: String
    public let x: Int
    public let y: Int
    public let flipped: Bool

    public init(itemID: String, x: Int, y: Int, flipped: Bool = false) {
        self.itemID = itemID; self.x = x; self.y = y; self.flipped = flipped
    }
}

public enum WorldError: Error, Equatable, Sendable {
    case outOfBounds, occupied, unknownItem, levelTooLow(required: Int), notOwned, maxLand, emptyTile
}

/// The player's garden: land size, owned (unplaced) items, placed items. Value type; every edit returns a new world.
public struct WorldState: Codable, Sendable, Hashable {
    public let landSize: Int
    public let inventory: [String: Int]
    public let placements: [Placement]

    public init(landSize: Int = 3, inventory: [String: Int] = [:], placements: [Placement] = [Placement(itemID: "fire-pit", x: 1, y: 1)]) {
        self.landSize = landSize; self.inventory = inventory; self.placements = placements
    }

    public func placement(atX x: Int, y: Int) -> Placement? {
        placements.first { $0.x == x && $0.y == y }
    }

    public func buying(_ itemID: String, level: Int) throws -> WorldState {
        guard let item = Catalog.item(itemID) else { throw WorldError.unknownItem }
        guard level >= item.minLevel else { throw WorldError.levelTooLow(required: item.minLevel) }
        var next = inventory
        next[itemID, default: 0] += 1
        return WorldState(landSize: landSize, inventory: next, placements: placements)
    }

    public func placing(_ itemID: String, x: Int, y: Int, flipped: Bool = false) throws -> WorldState {
        guard (0..<landSize).contains(x), (0..<landSize).contains(y) else { throw WorldError.outOfBounds }
        guard placement(atX: x, y: y) == nil else { throw WorldError.occupied }
        guard let owned = inventory[itemID], owned > 0 else { throw WorldError.notOwned }
        var next = inventory
        next[itemID] = owned - 1
        return WorldState(landSize: landSize, inventory: next,
                          placements: placements + [Placement(itemID: itemID, x: x, y: y, flipped: flipped)])
    }

    /// Pick an item back up into inventory.
    public func removing(atX x: Int, y: Int) throws -> WorldState {
        guard let existing = placement(atX: x, y: y) else { throw WorldError.emptyTile }
        var next = inventory
        next[existing.itemID, default: 0] += 1
        return WorldState(landSize: landSize, inventory: next,
                          placements: placements.filter { $0 != existing })
    }

    public var nextExpansion: (size: Int, price: Int)? {
        Catalog.landExpansions.first { $0.size > landSize }
    }

    /// Grows the land; existing items keep their coordinates (land grows down/right).
    public func expanded() throws -> WorldState {
        guard let next = nextExpansion else { throw WorldError.maxLand }
        return WorldState(landSize: next.size, inventory: inventory, placements: placements)
    }
}

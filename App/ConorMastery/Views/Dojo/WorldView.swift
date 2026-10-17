import MasteryCore
import SwiftUI

/// Top-down pixel garden (Ninja Adventure's view). Land grows from 3x3 to 9x9; items stand on tiles,
/// drawn back to front by row; in build mode a tap places the selected item or picks one up.
struct WorldView: View {
    let building: Bool
    @Binding var selectedItem: String?
    @Environment(MasteryStore.self) private var store

    var body: some View {
        GeometryReader { geo in
            let world = store.world
            let layout = GardenLayout(size: geo.size, landSize: world.landSize)
            ZStack(alignment: .topLeading) {
                Theme.water
                landEdge(layout)
                ground(layout)
                ForEach(sortedPlacements(world), id: \.self) { placement in
                    let height = ItemArt.pixelSize(placement.itemID).height * layout.scale
                    PixelSprite(placement.itemID, scale: layout.scale)
                        .scaleEffect(x: placement.flipped ? -1 : 1, y: 1)
                        .position(layout.anchor(placement, spriteHeight: height))
                        .accessibilityLabel(Catalog.item(placement.itemID)?.name ?? placement.itemID)
                }
                avatar(layout)
            }
            .contentShape(Rectangle())
            .gesture(SpatialTapGesture().onEnded { value in
                guard building, let tile = layout.tile(at: value.location) else { return }
                handleTap(x: tile.x, y: tile.y)
            })
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Your dojo garden, \(store.world.placements.count) items")
    }

    /// A strip of earth under the land's bottom edge, so the garden reads as raised ground over water.
    private func landEdge(_ layout: GardenLayout) -> some View {
        let land = layout.rect(x: 0, y: 0).union(layout.rect(x: layout.landSize - 1, y: layout.landSize - 1))
        let depth = 4 * layout.scale
        return Rectangle().fill(Theme.earth)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.ink.opacity(0.35)).frame(height: layout.scale) }
            .frame(width: land.width, height: land.height + depth)
            .position(x: land.midX, y: land.midY + depth / 2)
            .accessibilityHidden(true)
    }

    /// Grass tiles, with a few detail variants mixed in by position so the lawn doesn't look stamped.
    private func ground(_ layout: GardenLayout) -> some View {
        ForEach(0..<(layout.landSize * layout.landSize), id: \.self) { index in
            let x = index % layout.landSize
            let y = index / layout.landSize
            let rect = layout.rect(x: x, y: y)
            let variant = (x * 7 + y * 13) % 9
            PixelSprite("ground-grass-\(variant < 3 ? variant + 1 : 0)", scale: layout.scale)
                .overlay { if building { Rectangle().stroke(Theme.ink.opacity(0.3), lineWidth: 1) } }
                .position(x: rect.midX, y: rect.midY)
                .accessibilityHidden(true)
        }
    }

    /// Ground covers (gravel, moss) first, then everything else by bottom row so nearer items overlap farther ones.
    private func sortedPlacements(_ world: WorldState) -> [Placement] {
        func key(_ p: Placement) -> (Int, Int, Int) {
            (Catalog.item(p.itemID)?.category == .ground ? 0 : 1, p.y + p.height, p.x)
        }
        return world.placements.sorted { key($0) < key($1) }
    }

    /// You stand beside the fire pit (or the first tile), wearing your belt colour.
    private func avatar(_ layout: GardenLayout) -> some View {
        let fire = store.world.placements.first { $0.itemID == "fire-pit" }
        let spot = fire.map { layout.anchor($0, spriteHeight: 16 * layout.scale) }
            ?? layout.anchor(Placement(itemID: "", x: 0, y: 0), spriteHeight: 16 * layout.scale)
        let offset = fire.map { CGFloat($0.width) * layout.tile * 0.5 + layout.tile * 0.4 } ?? 0
        return PixelSprite(ItemArt.hero(store.level.belt), scale: layout.scale)
            .position(x: spot.x - offset, y: spot.y)
            .accessibilityLabel("You, \(store.level.belt.title)")
    }

    private func handleTap(x: Int, y: Int) {
        // With an item selected a tap places it (a lantern can stand on gravel); with none, it picks up.
        if let item = selectedItem {
            store.place(item, x: x, y: y)
            if (store.world.inventory[item] ?? 0) == 0 { selectedItem = nil }
        } else if store.world.placement(atX: x, y: y) != nil {
            store.pickUp(x: x, y: y)
        }
    }
}

/// Owned-but-unplaced items. Pick one, then tap a tile.
struct BuildPalette: View {
    @Binding var selectedItem: String?
    @Environment(MasteryStore.self) private var store

    var body: some View {
        let owned = store.world.inventory.filter { $0.value > 0 }.sorted { $0.key < $1.key }
        VStack(alignment: .leading, spacing: 6) {
            Text(owned.isEmpty ? "Buy items in the shop, then place them here." : "Pick an item, tap a tile. Tap it again to deselect, then tap a placed item to pick it up.")
                .font(.caption).foregroundStyle(.white.opacity(0.8))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(owned, id: \.key) { entry in
                        let id = entry.key
                        let count = entry.value
                        Button { selectedItem = selectedItem == id ? nil : id } label: {
                            VStack(spacing: 2) {
                                PixelSprite(id, fitting: 36).frame(width: 36, height: 36)
                                Text("x\(count)").font(.caption2.monospacedDigit())
                            }
                            .padding(8)
                            .background(selectedItem == id ? Theme.gold.opacity(0.5) : .white.opacity(0.1),
                                        in: RoundedRectangle(cornerRadius: 10))
                        }
                        .foregroundStyle(.white)
                        .accessibilityLabel("\(Catalog.item(id)?.name ?? id), \(count) owned")
                    }
                }
            }
        }
        .padding(12)
        .background(Theme.ink.opacity(0.85), in: RoundedRectangle(cornerRadius: 16))
    }
}

/// Square grid geometry. Tiles are 16 px sprites at the largest whole-number scale that fits (max 5x),
/// so every pixel stays square.
private struct GardenLayout {
    static let pixelsPerTile: CGFloat = 16
    static let maxScale: CGFloat = 5

    let landSize: Int
    let scale: CGFloat
    let tile: CGFloat
    let origin: CGPoint

    init(size: CGSize, landSize: Int) {
        self.landSize = landSize
        let fit = min(size.width * 0.92, size.height * 0.8) / (CGFloat(landSize) * Self.pixelsPerTile)
        scale = min(max(1, fit.rounded(.down)), Self.maxScale)
        tile = Self.pixelsPerTile * scale
        let side = tile * CGFloat(landSize)
        // Sit a little low: tall sprites on the back row reach above the land.
        origin = CGPoint(x: ((size.width - side) / 2).rounded(), y: (size.height * 0.6 - side / 2).rounded())
    }

    func rect(x: Int, y: Int) -> CGRect {
        CGRect(x: origin.x + CGFloat(x) * tile, y: origin.y + CGFloat(y) * tile, width: tile, height: tile)
    }

    /// Centre point for a sprite centred on its footprint, standing on the footprint's bottom edge.
    func anchor(_ placement: Placement, spriteHeight: CGFloat) -> CGPoint {
        let first = rect(x: placement.x, y: placement.y)
        let last = rect(x: placement.x + placement.width - 1, y: placement.y + placement.height - 1)
        return CGPoint(x: (first.minX + last.maxX) / 2, y: last.maxY - spriteHeight / 2)
    }

    func tile(at point: CGPoint) -> (x: Int, y: Int)? {
        let x = Int(floor((point.x - origin.x) / tile))
        let y = Int(floor((point.y - origin.y) / tile))
        guard (0..<landSize).contains(x), (0..<landSize).contains(y) else { return nil }
        return (x, y)
    }
}

import MasteryCore
import SwiftUI

/// Isometric garden. Land grows from 3x3 to 9x9; items sit on tiles; in build mode a tap places
/// the selected item or picks one up.
struct WorldView: View {
    let building: Bool
    @Binding var selectedItem: String?
    @Environment(MasteryStore.self) private var store

    private let tileWidth: CGFloat = 64
    private var tileHeight: CGFloat { tileWidth / 2 }

    var body: some View {
        GeometryReader { geo in
            let world = store.world
            let origin = origin(in: geo.size, landSize: world.landSize)
            ZStack(alignment: .topLeading) {
                Canvas { context, _ in
                    drawWater(context, size: geo.size)
                    for x in 0..<world.landSize {
                        for y in 0..<world.landSize {
                            drawTile(context, x: x, y: y, origin: origin, occupied: world.placement(atX: x, y: y) != nil)
                        }
                    }
                }
                ForEach(sortedPlacements(world), id: \.self) { placement in
                    Text(ItemArt.glyph(placement.itemID))
                        .font(.system(size: tileWidth * 0.62))
                        .scaleEffect(x: placement.flipped ? -1 : 1, y: 1)
                        .position(itemPoint(x: placement.x, y: placement.y, origin: origin))
                        .accessibilityLabel(Catalog.item(placement.itemID)?.name ?? placement.itemID)
                }
                avatar(origin: origin)
            }
            .contentShape(Rectangle())
            .gesture(SpatialTapGesture().onEnded { value in
                guard building, let tile = tile(at: value.location, origin: origin, landSize: world.landSize) else { return }
                handleTap(x: tile.x, y: tile.y)
            })
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Your dojo garden, \(store.world.placements.count) items")
    }

    // MARK: - Geometry

    private func origin(in size: CGSize, landSize: Int) -> CGPoint {
        let mapHeight = CGFloat(landSize) * tileHeight
        return CGPoint(x: size.width / 2, y: size.height * 0.58 - mapHeight / 2)
    }

    private func tileCenter(x: Int, y: Int, origin: CGPoint) -> CGPoint {
        CGPoint(x: origin.x + CGFloat(x - y) * tileWidth / 2,
                y: origin.y + CGFloat(x + y) * tileHeight / 2 + tileHeight / 2)
    }

    private func itemPoint(x: Int, y: Int, origin: CGPoint) -> CGPoint {
        let center = tileCenter(x: x, y: y, origin: origin)
        return CGPoint(x: center.x, y: center.y - tileHeight * 0.45)
    }

    private func tile(at point: CGPoint, origin: CGPoint, landSize: Int) -> (x: Int, y: Int)? {
        let px = (point.x - origin.x) / (tileWidth / 2)
        let py = (point.y - origin.y) / (tileHeight / 2)
        let x = Int(floor((px + py) / 2))
        let y = Int(floor((py - px) / 2))
        guard (0..<landSize).contains(x), (0..<landSize).contains(y) else { return nil }
        return (x, y)
    }

    /// Back-to-front so nearer items overlap farther ones.
    private func sortedPlacements(_ world: WorldState) -> [Placement] {
        world.placements.sorted { ($0.x + $0.y, $0.x) < ($1.x + $1.y, $1.x) }
    }

    // MARK: - Drawing

    private func drawWater(_ context: GraphicsContext, size: CGSize) {
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.16, green: 0.36, blue: 0.62).opacity(0.35)))
    }

    private func drawTile(_ context: GraphicsContext, x: Int, y: Int, origin: CGPoint, occupied: Bool) {
        let c = tileCenter(x: x, y: y, origin: origin)
        var diamond = Path()
        diamond.move(to: CGPoint(x: c.x, y: c.y - tileHeight / 2))
        diamond.addLine(to: CGPoint(x: c.x + tileWidth / 2, y: c.y))
        diamond.addLine(to: CGPoint(x: c.x, y: c.y + tileHeight / 2))
        diamond.addLine(to: CGPoint(x: c.x - tileWidth / 2, y: c.y))
        diamond.closeSubpath()
        let base = (x + y).isMultiple(of: 2) ? Theme.grass : Theme.grassDark
        context.fill(diamond, with: .color(base))
        context.stroke(diamond, with: .color(Theme.ink.opacity(building ? 0.5 : 0.2)), lineWidth: building ? 1 : 0.5)
    }

    private func avatar(origin: CGPoint) -> some View {
        let fire = store.world.placements.first { $0.itemID == "fire-pit" }
        let spot = fire.map { itemPoint(x: $0.x, y: $0.y, origin: origin) } ?? itemPoint(x: 0, y: 0, origin: origin)
        return Text("🧘")
            .font(.system(size: tileWidth * 0.55))
            .overlay(alignment: .bottom) {
                Capsule().fill(Theme.color(store.level.belt)).frame(width: 22, height: 4).offset(y: 2)
            }
            .position(x: spot.x - tileWidth * 0.42, y: spot.y + 2)
            .accessibilityLabel("You, \(store.level.belt.title)")
    }

    private func handleTap(x: Int, y: Int) {
        if store.world.placement(atX: x, y: y) != nil {
            store.pickUp(x: x, y: y)
        } else if let item = selectedItem {
            store.place(item, x: x, y: y)
            if (store.world.inventory[item] ?? 0) == 0 { selectedItem = nil }
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
            Text(owned.isEmpty ? "Buy items in the shop, then place them here." : "Pick an item, tap a tile. Tap an item to pick it up.")
                .font(.caption).foregroundStyle(.white.opacity(0.8))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(owned, id: \.key) { entry in
                        let id = entry.key
                        let count = entry.value
                        Button { selectedItem = id } label: {
                            VStack(spacing: 2) {
                                Text(ItemArt.glyph(id)).font(.title)
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

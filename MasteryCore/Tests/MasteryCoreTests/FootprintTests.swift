import Testing
@testable import MasteryCore

/// Items cover several tiles (top-left anchor). Ground covers sit on their own layer under objects.
@Suite struct FootprintTests {
    private func world(_ items: [String], land: Int = 9) throws -> WorldState {
        try items.reduce(WorldState(landSize: land, placements: [])) { try $0.buying($1, level: 99) }
    }

    @Test func bigItemsCoverEveryTileOfTheirFootprint() throws {
        let placed = try world(["dojo"]).placing("dojo", x: 2, y: 3)   // dojo is 4x2
        #expect(placed.placement(atX: 5, y: 4)?.itemID == "dojo")
        #expect(placed.placement(atX: 6, y: 4) == nil)
        #expect(placed.placement(atX: 2, y: 5) == nil)
    }

    @Test func overlappingFootprintsAreRefused() throws {
        let placed = try world(["dojo", "pine"]).placing("dojo", x: 2, y: 3)
        #expect(throws: WorldError.occupied) { try placed.placing("pine", x: 1, y: 4) }   // pine 2x1 reaches (2,4)
        #expect(throws: Never.self) { try placed.placing("pine", x: 0, y: 4) }
    }

    @Test func footprintMustFitOnTheLand() throws {
        #expect(throws: WorldError.outOfBounds) { try world(["pond"]).placing("pond", x: 7, y: 0) }   // pond 3x3
        #expect(throws: Never.self) { try world(["pond"]).placing("pond", x: 6, y: 6) }
    }

    @Test func objectsStandOnGroundCoversButCoversDoNotStack() throws {
        let gravelled = try world(["gravel", "gravel", "lantern"]).placing("gravel", x: 1, y: 1)
        let lit = try gravelled.placing("lantern", x: 1, y: 1)
        #expect(throws: WorldError.occupied) { try lit.placing("gravel", x: 1, y: 1) }
        // Picking up takes the object first, then the cover under it.
        let lanternBack = try lit.removing(atX: 1, y: 1)
        #expect(lanternBack.inventory["lantern"] == 1)
        #expect(lanternBack.placement(atX: 1, y: 1)?.itemID == "gravel")
    }

    @Test func pickingUpFromAnyTileOfTheFootprintRemovesTheItem() throws {
        let placed = try world(["pond"]).placing("pond", x: 0, y: 0)
        let back = try placed.removing(atX: 2, y: 2)
        #expect(back.placements.isEmpty)
        #expect(back.inventory["pond"] == 1)
    }

    @Test func everyCatalogItemHasAPositiveFootprint() {
        for item in Catalog.items { #expect(item.width >= 1 && item.height >= 1, "\(item.id)") }
    }
}

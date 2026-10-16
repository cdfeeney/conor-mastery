import Foundation
import Testing
@testable import MasteryCore

/// The plan the Python exporter writes must decode in Swift (cross-language contract check).
@Suite struct SeedPlanTests {
    static let seedURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("App/Resources/seed-plan.json")

    @Test func exportedSeedPlanDecodesAndValidates() throws {
        let data = try Data(contentsOf: Self.seedURL)
        let plan = try JSONDecoder().decode(MasteryPlan.self, from: data).validated()
        let ids = plan.habits.map(\.id)
        #expect(ids == ["morning-routine", "sleep", "meditation", "workout", "reset-focus",
                        "deep-breathing", "no-social-media", "no-nicotine", "night-routine"])
        let defs = plan.habits.map { $0.definition(anchor: DayKey("2026-10-16")!) }
        #expect(defs.allSatisfy { !$0.challenges.isEmpty })
        #expect(defs.filter { $0.kind == .checklist }.allSatisfy { $0.steps.count == 5 })
        #expect(defs.first { $0.id == "meditation" }?.minMinutes == 2)
        #expect(defs.first { $0.id == "sleep" }?.kind == .sleep)
    }

    @Test func gateHabitExistsInSeedPlan() throws {
        let plan = try JSONDecoder().decode(MasteryPlan.self, from: Data(contentsOf: Self.seedURL))
        #expect(plan.habits.contains { $0.id == GateConfig().morningHabitID })
    }
}

import Foundation
import Testing

@testable import DODSupport

/// L1 coverage for the "Pass it down" hand-off value type (DUT-968).
@Suite("LegacyHandoff (DUT-968)")
struct LegacyHandoffTests {

    private let url = URL(string: "https://dutchovendaddy.com/recipe/peach-cobbler")!

    @Test func trimsAndDropsBlankNotesAndTips() {
        let handoff = LegacyHandoff(
            recipeID: 42,
            recipeTitle: "Peach Cobbler",
            recipeURL: url,
            notes: ["  salt less ", "", "   "],
            coalTips: [" 8 on top ", "\n"]
        )
        #expect(handoff.notes == ["salt less"])
        #expect(handoff.coalTips == ["8 on top"])
    }

    @Test func codableRoundTrip() throws {
        let original = LegacyHandoff(
            recipeID: 42,
            recipeTitle: "Peach Cobbler",
            recipeURL: url,
            fromName: "Grandpa",
            message: "Make it for Sunday.",
            notes: ["less sugar"],
            coalTips: ["10 bottom, 14 top"],
            photoLocalIDs: ["photo-1"]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LegacyHandoff.self, from: data)
        #expect(decoded == original)
    }

    @Test func versionIsCurrent() {
        let handoff = LegacyHandoff(recipeID: 1, recipeTitle: "X", recipeURL: url)
        #expect(handoff.version == LegacyHandoff.currentVersion)
    }
}

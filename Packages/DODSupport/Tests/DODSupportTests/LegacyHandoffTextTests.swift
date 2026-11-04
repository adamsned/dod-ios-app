import Foundation
import Testing

@testable import DODSupport

@Suite("LegacyHandoffText (DUT-968)")
struct LegacyHandoffTextTests {

    private let url = URL(string: "https://example.com/pot-roast") ?? URL(fileURLWithPath: "/")

    @Test func minimalHandoffHasOnlyTitleAndURL() {
        let handoff = LegacyHandoff(recipeID: 1, recipeTitle: "Pot Roast", recipeURL: url)
        #expect(
            LegacyHandoffText.render(handoff)
                == "Recipe: Pot Roast\nhttps://example.com/pot-roast"
        )
    }

    @Test func fullHandoffIncludesEveryNonEmptySectionInOrder() throws {
        let handoff = LegacyHandoff(
            recipeID: 1,
            recipeTitle: "Pot Roast",
            recipeURL: url,
            fromName: "Dad",
            message: "Make this Sunday.",
            notes: ["less salt"],
            coalTips: ["8 on top"]
        )
        let text = LegacyHandoffText.render(handoff)
        let message = try #require(text.range(of: "Make this Sunday."))
        let recipe = try #require(text.range(of: "Recipe:"))
        let notes = try #require(text.range(of: "My notes:"))
        let tips = try #require(text.range(of: "Coal tips:"))
        #expect(message.lowerBound < recipe.lowerBound)
        #expect(recipe.lowerBound < notes.lowerBound)
        #expect(notes.lowerBound < tips.lowerBound)
        #expect(text.hasSuffix("— Dad"))
    }

    @Test func omitsEmptySectionHeaders() {
        let handoff = LegacyHandoff(
            recipeID: 1,
            recipeTitle: "Pot Roast",
            recipeURL: url,
            notes: ["less salt"]
        )
        #expect(!LegacyHandoffText.render(handoff).contains("Coal tips:"))
    }
}

import DODDomain
import DODSupport
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

@Suite("LegacyHandoffBuilder")
struct LegacyHandoffBuilderTests {

    private func log(
        recipeID: Int,
        at seconds: TimeInterval,
        note: String? = nil,
        photo: String? = nil
    ) -> CookLogEntry {
        CookLogEntry(
            id: UUID(),
            recipeID: recipeID,
            recipeTitle: "Recipe \(recipeID)",
            cookedAt: Date(timeIntervalSince1970: seconds),
            note: note,
            photoLocalID: photo
        )
    }

    private func build(_ logs: [CookLogEntry]) -> LegacyHandoff {
        let recipe = RecipeDetailTestFixtures.makeRecipe(id: 7, withDetail: true)
        return LegacyHandoffBuilder.build(
            recipe: recipe,
            logs: logs,
            fromName: "Dad",
            message: "Enjoy",
            coalTips: ["Use 18 briquettes"]
        )
    }

    @Test func ignoresLogsForOtherRecipes() {
        let handoff = build([
            log(recipeID: 7, at: 100, note: "mine"),
            log(recipeID: 8, at: 200, note: "other"),
        ])
        #expect(handoff.notes == ["mine"])
    }

    @Test func notesAreNewestFirst() {
        let handoff = build([
            log(recipeID: 7, at: 100, note: "older"),
            log(recipeID: 7, at: 200, note: "newer"),
        ])
        #expect(handoff.notes == ["newer", "older"])
    }

    @Test func collectsPhotoIDsAndSkipsNils() {
        let handoff = build([
            log(recipeID: 7, at: 100, photo: "p1"),
            log(recipeID: 7, at: 200, photo: nil),
            log(recipeID: 7, at: 300, photo: "p3"),
        ])
        #expect(handoff.photoLocalIDs == ["p3", "p1"])
    }
}

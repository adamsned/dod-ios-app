import DODDomain
import DODSupport
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

@Suite("Classify fallback step image edge cases (DUT-1576)")
struct ClassifyStepImageEdgeTests {
    private func build(_ card: WPRMRecipeCardParser.Card) throws -> Recipe {
        let canonical = try #require(URL(string: "https://www.dutchovendaddy.com/r/2/"))
        return RecipeDetailViewModel.recipe(
            fromCard: card,
            listItem: RecipeDetailTestFixtures.makeListItem(id: 2),
            canonicalURL: canonical
        )
    }

    @Test
    func missingImageListYieldsNilImageURLs() throws {
        let card = WPRMRecipeCardParser.Card(ingredients: ["a"], instructions: ["s1", "s2"])
        let recipe = try build(card)
        #expect(recipe.instructions.map(\.imageURL) == [nil, nil])
    }

    @Test
    func shorterImageListDoesNotCrashAndLeavesTailNil() throws {
        let url = try #require(URL(string: "https://e.com/a.jpg"))
        let card = WPRMRecipeCardParser.Card(
            ingredients: ["a"],
            instructions: ["s1", "s2"],
            instructionImages: [url]
        )
        let recipe = try build(card)
        #expect(recipe.instructions[0].imageURL == url)
        #expect(recipe.instructions[1].imageURL == nil)
    }
}

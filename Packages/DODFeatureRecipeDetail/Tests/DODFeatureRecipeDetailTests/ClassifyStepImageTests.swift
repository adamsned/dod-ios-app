import DODDomain
import DODSupport
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

@Suite("Classify fallback carries step images (DUT-1576)")
struct ClassifyStepImageTests {
    @Test
    func cardStepImageIsCarriedOntoRecipeInstruction() throws {
        let url = try #require(URL(string: "https://e.com/a.jpg"))
        let card = WPRMRecipeCardParser.Card(
            ingredients: ["a"],
            instructions: ["s1"],
            instructionImages: [url]
        )
        let canonical = try #require(URL(string: "https://www.dutchovendaddy.com/r/1/"))
        let recipe = RecipeDetailViewModel.recipe(
            fromCard: card,
            listItem: RecipeDetailTestFixtures.makeListItem(id: 1),
            canonicalURL: canonical
        )
        #expect(recipe.instructions[0].imageURL == url)
    }
}

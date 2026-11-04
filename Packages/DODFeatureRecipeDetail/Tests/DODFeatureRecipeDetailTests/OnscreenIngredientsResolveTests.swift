import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

@MainActor
@Suite
struct OnscreenIngredientsResolveTests {

    private func entry(_ text: String) -> OnscreenIngredients.Entry {
        let recipe = RecipeDetailTestFixtures.makeRecipe(id: 1, withDetail: true)
        return .make(recipe: recipe, ingredient: RecipeIngredient(text: text), displayText: text)
    }

    @Test func thatAndNilReturnMostRecentEntry() {
        let registry = OnscreenIngredients()
        registry.appear(entry("1 tsp salt"))
        let last = entry("2 cups all-purpose Flour")
        registry.appear(last)
        #expect(registry.resolve("that")?.id == last.id)
        #expect(registry.resolve(nil)?.id == last.id)
    }

    @Test func namedQueryMatchesCaseInsensitively() {
        let registry = OnscreenIngredients()
        registry.appear(entry("1 tsp salt"))
        let flour = entry("2 cups all-purpose Flour")
        registry.appear(flour)
        #expect(registry.resolve("flour")?.id == flour.id)
    }

    @Test func unknownQueryReturnsNil() {
        let registry = OnscreenIngredients()
        registry.appear(entry("2 cups all-purpose Flour"))
        #expect(registry.resolve("saffron") == nil)
    }
}

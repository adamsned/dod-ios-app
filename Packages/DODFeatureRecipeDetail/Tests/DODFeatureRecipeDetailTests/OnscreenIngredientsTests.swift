import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

@MainActor
@Suite
struct OnscreenIngredientsTests {

    private func entry(recipeID: Int = 1, text: String = "2 cups flour") -> OnscreenIngredients.Entry {
        let recipe = RecipeDetailTestFixtures.makeRecipe(id: recipeID, withDetail: true)
        return .make(recipe: recipe, ingredient: RecipeIngredient(text: text), displayText: text)
    }

    @Test func appearTwiceWithSameIDLeavesOneEntry() {
        let registry = OnscreenIngredients()
        let entry = entry()
        registry.appear(entry)
        registry.appear(entry)
        #expect(registry.entries.count == 1)
    }

    @Test func disappearRemovesEntry() {
        let registry = OnscreenIngredients()
        let entry = entry()
        registry.appear(entry)
        registry.disappear(id: entry.id)
        #expect(registry.entries.isEmpty)
    }

    @Test func clearRemovesOnlyThatRecipe() {
        let registry = OnscreenIngredients()
        registry.appear(entry(recipeID: 1))
        registry.appear(entry(recipeID: 2))
        registry.clear(recipeID: 1)
        #expect(registry.entries.map(\.recipeID) == [2])
    }

    @Test func makeBuildsSingleIngredientRecipe() {
        let recipe = RecipeDetailTestFixtures.makeRecipe(id: 5, withDetail: true)
        let ingredient = RecipeIngredient(text: "1 cup sugar")
        let entry = OnscreenIngredients.Entry.make(recipe: recipe, ingredient: ingredient, displayText: "240 g sugar")
        #expect(entry.recipe.ingredients.count == 1)
        #expect(entry.recipe.ingredients.first?.text == "240 g sugar")
        #expect(entry.recipe.ingredients.first?.id == ingredient.id)
        #expect(entry.id == ingredient.id)
        #expect(entry.recipeID == 5)
    }
}

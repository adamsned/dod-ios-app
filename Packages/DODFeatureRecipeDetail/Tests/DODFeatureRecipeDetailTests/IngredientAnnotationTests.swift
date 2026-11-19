import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

@MainActor
@Suite
struct IngredientAnnotationTests {

    private func makeEntry(ingredient: RecipeIngredient) -> OnscreenIngredients.Entry {
        let recipe = RecipeDetailTestFixtures.makeRecipe(id: 1, withDetail: true)
        return .make(recipe: recipe, ingredient: ingredient, displayText: ingredient.text)
    }

    @Test func actionsMapToRegistry() {
        let registry = OnscreenIngredients()
        let entry = makeEntry(ingredient: RecipeIngredient(text: "2 cups flour"))
        let annotation = IngredientAnnotation(entry: entry, registry: registry)

        annotation.registry.appear(annotation.entry)
        #expect(registry.entries.map(\.id) == [entry.id])

        annotation.registry.disappear(id: annotation.entry.id)
        #expect(registry.entries.isEmpty)
    }

    @Test func entryIDMatchesIngredientID() {
        let ingredient = RecipeIngredient(text: "1 tsp salt")
        let entry = makeEntry(ingredient: ingredient)
        #expect(entry.id == ingredient.id)
    }
}

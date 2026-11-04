import Foundation
import Testing

@testable import DODDomain

@Suite struct RecipeSectionTests {
    @Test func codableRoundTrip() throws {
        let ingredients = RecipeIngredient.list(from: ["Flour", "Butter"])
        let section = RecipeSection(
            label: "For the Crust",
            ingredientIDs: ingredients.map(\.id),
            instructionIDs: [UUID()]
        )
        let data = try JSONEncoder().encode(section)
        let decoded = try JSONDecoder().decode(RecipeSection.self, from: data)
        #expect(decoded == section)
    }

    @Test func idIsStableForEqualSections() {
        let ids = RecipeIngredient.list(from: ["Flour"]).map(\.id)
        let firstSection = RecipeSection(label: "Crust", ingredientIDs: ids)
        let secondSection = RecipeSection(label: "Crust", ingredientIDs: ids)
        #expect(firstSection.id == secondSection.id)
    }

    @Test func makeSplitsIngredientsByGroupCounts() {
        let ings = RecipeIngredient.list(from: ["Flour", "Butter", "Apples"])
        let result = RecipeSection.make(
            groups: [("For the Crust", 2), ("For the Filling", 1)],
            ingredients: ings
        )
        #expect(result.count == 2)
        #expect(result[0].label == "For the Crust")
        #expect(result[0].ingredientIDs == [ings[0].id, ings[1].id])
        #expect(result[1].label == "For the Filling")
        #expect(result[1].ingredientIDs == [ings[2].id])
    }

    @Test func makeSkipsBlankLabel() {
        let ings = RecipeIngredient.list(from: ["Flour", "Butter"])
        let result = RecipeSection.make(
            groups: [("   ", 1), ("Filling", 1)],
            ingredients: ings
        )
        #expect(result.count == 1)
        #expect(result[0].label == "Filling")
        #expect(result[0].ingredientIDs == [ings[1].id])
    }

    @Test func makeClampsCountPastEnd() {
        let ings = RecipeIngredient.list(from: ["Flour", "Butter"])
        let result = RecipeSection.make(groups: [("Crust", 99)], ingredients: ings)
        #expect(result.count == 1)
        #expect(result[0].ingredientIDs.count == 2)
    }

    @Test func makeSkipsZeroCountGroup() {
        let ings = RecipeIngredient.list(from: ["Flour"])
        let result = RecipeSection.make(groups: [("Empty", 0)], ingredients: ings)
        #expect(result.isEmpty)
    }

    @Test func nilLabelGroupConsumesIngredientsButIsSkipped() {
        let ings = RecipeIngredient.list(from: ["Flour", "Butter", "Apples"])
        let result = RecipeSection.make(
            groups: [(nil, 1), ("Filling", 2)],
            ingredients: ings
        )
        #expect(result.count == 1)
        #expect(result[0].label == "Filling")
        #expect(result[0].ingredientIDs == [ings[1].id, ings[2].id])
    }
}

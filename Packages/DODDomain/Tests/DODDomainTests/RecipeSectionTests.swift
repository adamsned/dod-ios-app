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
}

import Foundation
import Testing

@testable import DODDomain

@Suite("FamilyRecipe") struct FamilyRecipeTests {
    @Test func codableRoundTrip() throws {
        let recipe = FamilyRecipe(
            title: "Test Recipe",
            ingredients: [],
            instructions: []
        )
        let encoded = try JSONEncoder().encode(recipe)
        let decoded = try JSONDecoder().decode(FamilyRecipe.self, from: encoded)
        #expect(decoded == recipe)
    }
}

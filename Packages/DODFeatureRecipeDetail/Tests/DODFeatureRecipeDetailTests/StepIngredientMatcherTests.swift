import DODDomain
import XCTest

@testable import DODFeatureRecipeDetail

final class StepIngredientMatcherTests: XCTestCase {

    func testMatchesIngredientByNameIgnoringQuantity() {
        let ingredients = [
            RecipeIngredient(id: UUID(), text: "2 tbsp butter")
        ]
        let result = StepIngredientMatcher.matches(
            stepText: "Melt the butter in a pan.",
            ingredients: ingredients
        )
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].text, "2 tbsp butter")
    }

    func testMatchesPluralToSingular() {
        let ingredients = [
            RecipeIngredient(id: UUID(), text: "3 cloves garlic")
        ]
        let result = StepIngredientMatcher.matches(
            stepText: "Add garlic.",
            ingredients: ingredients
        )
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].text, "3 cloves garlic")
    }

    func testMultiWordNameRequiresAllWords() {
        let ingredients = [
            RecipeIngredient(id: UUID(), text: "1 cup brown sugar")
        ]
        let result = StepIngredientMatcher.matches(
            stepText: "Add the sugar.",
            ingredients: ingredients
        )
        XCTAssertEqual(result.count, 0)
    }

    func testNoMatchReturnsEmpty() {
        let ingredients = [
            RecipeIngredient(id: UUID(), text: "2 tbsp butter")
        ]
        let result = StepIngredientMatcher.matches(
            stepText: "Add flour.",
            ingredients: ingredients
        )
        XCTAssertEqual(result.count, 0)
    }

    func testMappingIsIndexAlignedWithInstructions() {
        let instructions = [
            RecipeInstruction(id: UUID(), step: 1, text: "Melt the butter in a pan."),
            RecipeInstruction(id: UUID(), step: 2, text: "Add garlic."),
        ]
        let ingredients = [
            RecipeIngredient(id: UUID(), text: "2 tbsp butter"),
            RecipeIngredient(id: UUID(), text: "3 cloves garlic"),
        ]
        let result = StepIngredientMatcher.mapping(
            instructions: instructions,
            ingredients: ingredients
        )
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].count, 1)
        XCTAssertEqual(result[1].count, 1)
    }
}

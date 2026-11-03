import DODDomain
import XCTest

@testable import DODSupport

final class RecipeDietEvaluatorEvaluateTests: XCTestCase {
    func makeRecipe(ingredients: [String], diet: [String] = []) -> Recipe {
        Recipe(
            id: 1,
            slug: "test",
            title: "Test",
            excerpt: "",
            canonicalURL: URL(fileURLWithPath: "/test"),
            publishedAt: Date(timeIntervalSince1970: 0),
            ingredients: ingredients.enumerated().map { RecipeIngredient(text: $1, index: $0) },
            suitableForDiet: diet
        )
    }

    func testEmptyProfileNeverFitsAndHasNoHits() {
        let result = RecipeDietEvaluator.evaluate(makeRecipe(ingredients: ["2 cups Flour"]), against: DietaryProfile())
        XCTAssertTrue(result.allergenHits.isEmpty)
        XCTAssertFalse(result.fitsDiet)
        XCTAssertFalse(result.isIncomplete)
    }

    func testAllergenHitIsCaseInsensitive() {
        let profile = DietaryProfile(allergens: [.dairy, .nuts])
        let result = RecipeDietEvaluator.evaluate(makeRecipe(ingredients: ["1 tbsp BUTTER"]), against: profile)
        XCTAssertEqual(result.allergenHits, [.dairy])
    }
}

import DODDomain
import XCTest

@testable import DODSupport

final class RecipeDietEvaluatorTests: XCTestCase {
    private func makeRecipe(_ ingredients: [String]) -> Recipe {
        Recipe(
            id: 1,
            slug: "x",
            title: "x",
            excerpt: "",
            canonicalURL: URL(fileURLWithPath: "/x"),
            publishedAt: Date(),
            ingredients: RecipeIngredient.list(from: ingredients)
        )
    }

    func testAlmondsHitNutsAllergen() {
        let profile = DietaryProfile(allergens: [.nuts])
        let result = RecipeDietEvaluator.evaluate(makeRecipe(["1 cup almonds"]), against: profile)
        XCTAssertEqual(result.allergenHits, [.nuts])
    }

    func testNoIngredientsIsIncompleteAndNeverFits() {
        let profile = DietaryProfile(patterns: [.vegan])
        let result = RecipeDietEvaluator.evaluate(makeRecipe([]), against: profile)
        XCTAssertTrue(result.isIncomplete)
        XCTAssertFalse(result.fitsDiet)
    }
}

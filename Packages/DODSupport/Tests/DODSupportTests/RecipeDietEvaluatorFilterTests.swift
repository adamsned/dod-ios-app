import DODDomain
import XCTest

@testable import DODSupport

final class RecipeDietEvaluatorFilterTests: XCTestCase {
    private func makeRecipe(_ id: Int, _ ingredients: [String]) -> Recipe {
        Recipe(
            id: id,
            slug: "x\(id)",
            title: "x",
            excerpt: "",
            canonicalURL: URL(fileURLWithPath: "/x"),
            publishedAt: Date(),
            ingredients: RecipeIngredient.list(from: ingredients)
        )
    }

    func testEmptyProfileReturnsAllRecipesUnchanged() {
        let recipes = [makeRecipe(1, ["2 tbsp butter"]), makeRecipe(2, [])]
        let result = RecipeDietEvaluator.filter(recipes, profile: DietaryProfile(onlyShowFitting: true))
        XCTAssertEqual(result.map(\.id), [1, 2])
    }

    func testVeganOnlyShowFittingDropsButterRecipe() {
        let recipes = [makeRecipe(1, ["2 tbsp butter"]), makeRecipe(2, ["1 cup lentils"])]
        let profile = DietaryProfile(patterns: [.vegan], onlyShowFitting: true)
        let result = RecipeDietEvaluator.filter(recipes, profile: profile)
        XCTAssertEqual(result.map(\.id), [2])
    }
}

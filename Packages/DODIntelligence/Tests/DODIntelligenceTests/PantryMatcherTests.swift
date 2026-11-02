import DODDomain
import XCTest

@testable import DODIntelligence

final class PantryMatcherTests: XCTestCase {

    func testNormalizeDedupesAndLowercases() {
        let input = ["  Apple  ", "banana", "APPLE", "cherry", "banana"]
        let result = PantryMatcher.normalize(input)
        XCTAssertEqual(result, ["apple", "banana", "cherry"])
    }

    func testRankOrdersByCoverage() {
        let recipe1 = Recipe(
            id: 1,
            slug: "recipe-1",
            title: "Recipe 1",
            excerpt: "Excerpt 1",
            canonicalURL: URL(string: "https://example.com/1")!,
            ingredients: [
                RecipeIngredient(text: "2 cups flour"),
                RecipeIngredient(text: "1 cup sugar"),
            ],
            kind: .recipe
        )

        let recipe2 = Recipe(
            id: 2,
            slug: "recipe-2",
            title: "Recipe 2",
            excerpt: "Excerpt 2",
            canonicalURL: URL(string: "https://example.com/2")!,
            ingredients: [
                RecipeIngredient(text: "1 cup flour"),
                RecipeIngredient(text: "1 cup sugar"),
                RecipeIngredient(text: "1 egg"),
            ],
            kind: .recipe
        )

        let recipes = [recipe1, recipe2]
        let pantry = ["flour", "sugar"]

        let result = PantryMatcher.rank(recipes: recipes, pantry: pantry)

        // Recipe 1 should have higher coverage (2/2) than Recipe 2 (2/3)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].recipeID, 1)  // Higher coverage recipe first
        XCTAssertEqual(result[1].recipeID, 2)
    }

    func testRankDropsZeroMatchAndArticles() {
        let recipeWithNoMatch = Recipe(
            id: 1,
            slug: "recipe-1",
            title: "Recipe 1",
            excerpt: "Excerpt 1",
            canonicalURL: URL(string: "https://example.com/1")!,
            ingredients: [
                RecipeIngredient(text: "2 cups flour"),
                RecipeIngredient(text: "1 cup sugar"),
            ],
            kind: .recipe
        )

        let article = Recipe(
            id: 2,
            slug: "article-1",
            title: "Article 1",
            excerpt: "Excerpt 1",
            canonicalURL: URL(string: "https://example.com/2")!,
            ingredients: [],
            kind: .article
        )

        let recipeWithMatch = Recipe(
            id: 3,
            slug: "recipe-2",
            title: "Recipe 2",
            excerpt: "Excerpt 2",
            canonicalURL: URL(string: "https://example.com/3")!,
            ingredients: [
                RecipeIngredient(text: "1 cup flour")
            ],
            kind: .recipe
        )

        let recipes = [recipeWithNoMatch, article, recipeWithMatch]
        let pantry = ["butter"]  // No matches

        let result = PantryMatcher.rank(recipes: recipes, pantry: pantry)

        // Should only return the recipe with match, not the article or recipe with no matches
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].recipeID, 3)
    }

    func testRankEmptyPantryReturnsEmpty() {
        let recipe = Recipe(
            id: 1,
            slug: "recipe-1",
            title: "Recipe 1",
            excerpt: "Excerpt 1",
            canonicalURL: URL(string: "https://example.com/1")!,
            ingredients: [
                RecipeIngredient(text: "2 cups flour"),
                RecipeIngredient(text: "1 cup sugar"),
            ],
            kind: .recipe
        )

        let recipes = [recipe]
        let pantry: [String] = []

        let result = PantryMatcher.rank(recipes: recipes, pantry: pantry)

        XCTAssertTrue(result.isEmpty)
    }
}

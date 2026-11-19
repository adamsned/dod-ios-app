import DODDomain
import DODIntelligence
import Foundation
import XCTest

@testable import DODFeatureRecipeDetail

final class RecipeDetailLLMFallbackTests: XCTestCase {

    func test_needsLLMFallback_returnsTrueWhenRecipeHasNoIngredientsOrInstructions() {
        let recipe = Recipe(
            id: 1,
            slug: "test",
            title: "Test Recipe",
            excerpt: "A test recipe",
            canonicalURL: URL(string: "https://example.com/test")!,
            heroImage: nil,
            heroImageLargeURL: nil,
            categoryIDs: [],
            publishedAt: Date(),
            updatedAt: Date(),
            ingredients: [],
            instructions: []
        )

        XCTAssertTrue(RecipeDetailViewModel.needsLLMFallback(recipe))
    }

    func test_needsLLMFallback_returnsFalseWhenRecipeHasIngredients() {
        let recipe = Recipe(
            id: 1,
            slug: "test",
            title: "Test Recipe",
            excerpt: "A test recipe",
            canonicalURL: URL(string: "https://example.com/test")!,
            heroImage: nil,
            heroImageLargeURL: nil,
            categoryIDs: [],
            publishedAt: Date(),
            updatedAt: Date(),
            ingredients: [RecipeIngredient(text: "flour")],
            instructions: []
        )

        XCTAssertFalse(RecipeDetailViewModel.needsLLMFallback(recipe))
    }

    func test_needsLLMFallback_returnsFalseWhenRecipeHasInstructions() {
        let recipe = Recipe(
            id: 1,
            slug: "test",
            title: "Test Recipe",
            excerpt: "A test recipe",
            canonicalURL: URL(string: "https://example.com/test")!,
            heroImage: nil,
            heroImageLargeURL: nil,
            categoryIDs: [],
            publishedAt: Date(),
            updatedAt: Date(),
            ingredients: [],
            instructions: [RecipeInstruction(step: 1, text: "Mix ingredients")]
        )

        XCTAssertFalse(RecipeDetailViewModel.needsLLMFallback(recipe))
    }

    func test_recipeFromExtracted_createsRecipeWithExtractedData() {
        let extracted = ExtractedRecipe(
            ingredients: ["flour", "sugar"],
            instructions: ["Mix ingredients", "Bake"]
        )

        let listItem = RecipeListItem(
            id: 1,
            title: "Test Recipe",
            excerpt: "A test recipe",
            publishedAt: Date()
        )

        let canonicalURL = URL(string: "https://example.com/test")!

        let recipe = RecipeDetailViewModel.recipe(
            fromExtracted: extracted,
            listItem: listItem,
            canonicalURL: canonicalURL
        )

        XCTAssertEqual(recipe.ingredients.count, 2)
        XCTAssertEqual(recipe.instructions.count, 2)
        XCTAssertEqual(recipe.title, "Test Recipe")
        XCTAssertEqual(recipe.slug, "test")
    }
}

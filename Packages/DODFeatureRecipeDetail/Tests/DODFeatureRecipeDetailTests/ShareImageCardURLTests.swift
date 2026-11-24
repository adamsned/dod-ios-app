#if os(iOS) && canImport(UIKit)
import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

@Suite("ShareImageCardURL")
struct ShareImageCardURLTests {
    @MainActor
    @Test func imageCardShareURLWritesPNG() throws {
        let recipe = Self.makeRecipe(slug: "share-card-test")
        let url = try #require(
            RecipeDetailView.imageCardShareURL(recipe: recipe, heroImage: nil)
        )
        #expect(url.lastPathComponent == "share-card-test-card.png")
        #expect(FileManager.default.fileExists(atPath: url.path))
        try? FileManager.default.removeItem(at: url)
    }

    private static func makeRecipe(slug: String) -> Recipe {
        Recipe(
            id: 1,
            slug: slug,
            title: "Test Recipe",
            excerpt: "",
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/1/") ?? URL(fileURLWithPath: "/"),
            heroImage: nil,
            heroImageLargeURL: nil,
            categoryIDs: [],
            publishedAt: Date(timeIntervalSince1970: 0),
            ingredients: [
                RecipeIngredient(id: UUID(), text: "Ingredient 0"),
                RecipeIngredient(id: UUID(), text: "Ingredient 1"),
                RecipeIngredient(id: UUID(), text: "Ingredient 2"),
            ],
            instructions: [
                RecipeInstruction(id: UUID(), step: 1, text: "Step 1 text."),
                RecipeInstruction(id: UUID(), step: 2, text: "Step 2 text."),
            ],
            prepTime: nil,
            cookTime: nil,
            totalTime: nil,
            servings: 4,
            nutrition: nil,
            video: nil,
            kind: .recipe,
            articleBodyHTML: nil,
            recipeCategory: [],
            recipeCuisine: [],
            suitableForDiet: [],
            author: nil
        )
    }
}
#endif

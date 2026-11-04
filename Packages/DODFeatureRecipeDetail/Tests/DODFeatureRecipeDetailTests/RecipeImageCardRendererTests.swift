#if os(iOS) && canImport(UIKit)
import DODDomain
import Foundation
import Testing
import UIKit

@testable import DODFeatureRecipeDetail

/// Tests for RecipeImageCardRenderer.
@Suite("RecipeImageCardRenderer")
struct RecipeImageCardRendererTests {

    private func recipe(ingredients: Int, steps: Int, title: String = "Test Recipe") -> Recipe {
        Recipe(
            id: 1,
            slug: "test-recipe",
            title: title,
            excerpt: "",
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/1/") ?? URL(fileURLWithPath: "/"),
            heroImage: nil,
            heroImageLargeURL: nil,
            categoryIDs: [],
            publishedAt: Date(timeIntervalSince1970: 0),
            ingredients: (0..<ingredients).map {
                RecipeIngredient(id: UUID(), text: "Ingredient \($0)")
            },
            instructions: (0..<steps).map {
                RecipeInstruction(id: UUID(), step: $0 + 1, text: "Step \($0 + 1) text.")
            },
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

    @MainActor
    @Test func testRenderProducesCardResolution() {
        let recipe = recipe(ingredients: 5, steps: 4)
        let image = RecipeImageCardRenderer.render(
            recipe: recipe,
            heroImage: nil,
            logo: nil
        )

        #expect(image != nil)
        guard let image = image else { return }
        #expect(image.size == CGSize(width: 1080, height: 1920))
        #expect(image.scale == 1)
    }

    @MainActor
    @Test func testWritePNGCreatesFile() {
        let recipe = recipe(ingredients: 5, steps: 4)
        let image = RecipeImageCardRenderer.render(
            recipe: recipe,
            heroImage: nil,
            logo: nil
        )

        #expect(image != nil)

        guard let image = image else { return }
        let url = RecipeImageCardRenderer.writePNG(image, slug: "pot-roast")
        #expect(url != nil)
        guard let url = url else { return }
        #expect(url.lastPathComponent == "pot-roast-card.png")

        // Verify file exists
        #expect(FileManager.default.fileExists(atPath: url.path))

        // Clean up
        try? FileManager.default.removeItem(at: url)
    }

    @MainActor
    @Test func testWritePNGUsesFallbackNameForEmptySlug() {
        let recipe = recipe(ingredients: 5, steps: 4)
        let image = RecipeImageCardRenderer.render(
            recipe: recipe,
            heroImage: nil,
            logo: nil
        )

        #expect(image != nil)

        guard let image = image else { return }
        let url = RecipeImageCardRenderer.writePNG(image, slug: "")
        #expect(url != nil)
        guard let url = url else { return }
        #expect(url.lastPathComponent == "recipe-card.png")

        // Verify file exists
        #expect(FileManager.default.fileExists(atPath: url.path))

        // Clean up
        try? FileManager.default.removeItem(at: url)
    }
}
#endif

import Foundation
import Testing

@testable import DODDomain

@Suite("Recipe value type") struct RecipeTests {

    private static let baseURL =
        URL(
            string: "https://www.dutchovendaddy.com/skillet-corn/"
        ) ?? URL(filePath: "/dev/null")

    @Test func equalityIsValueBased() {
        let recipe1 = Self.makeRecipe(id: 42)
        let recipe2 = Self.makeRecipe(id: 42)
        #expect(recipe1 == recipe2)
        #expect(recipe1.hashValue == recipe2.hashValue)
    }

    @Test func differentIdsAreUnequal() {
        #expect(Self.makeRecipe(id: 1) != Self.makeRecipe(id: 2))
    }

    @Test func codableRoundTrip() throws {
        let original = Self.makeRecipe(id: 7)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Recipe.self, from: encoded)
        #expect(decoded == original)
    }

    /// DUT-572 / CL-310: old on-disk payloads predate the four editorial keys
    /// (recipeCategory / recipeCuisine / suitableForDiet / author). They must
    /// decode cleanly with `[]` / nil defaults (mirrors the pre-`kind` posture).
    @Test func backCompatDecodeWithoutEditorialKeys() throws {
        let json = """
            {
              "id": 5,
              "slug": "old",
              "title": "Old Cached Recipe",
              "excerpt": "Pre-DUT-572 blob.",
              "canonicalURL": "https://www.dutchovendaddy.com/old/",
              "categoryIDs": [],
              "publishedAt": 700000000,
              "ingredients": [],
              "instructions": []
            }
            """
        let decoded = try JSONDecoder().decode(Recipe.self, from: Data(json.utf8))
        #expect(decoded.recipeCategory.isEmpty)
        #expect(decoded.recipeCuisine.isEmpty)
        #expect(decoded.suitableForDiet.isEmpty)
        #expect(decoded.author == nil)
    }

    /// Encode → decode preserves the four editorial fields.
    @Test func editorialFieldsRoundTrip() throws {
        let original = Recipe(
            id: 8,
            slug: "skillet-corn",
            title: "Garlic Butter Skillet Corn",
            excerpt: "An easy side dish.",
            canonicalURL: Self.baseURL,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            recipeCategory: ["Side Dish"],
            recipeCuisine: ["American"],
            suitableForDiet: ["https://schema.org/LowFatDiet"],
            author: "Chef Ned"
        )
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Recipe.self, from: encoded)
        #expect(decoded == original)
        #expect(decoded.recipeCategory == ["Side Dish"])
        #expect(decoded.recipeCuisine == ["American"])
        #expect(decoded.suitableForDiet == ["https://schema.org/LowFatDiet"])
        #expect(decoded.author == "Chef Ned")
    }

    @Test func hasDetailFalseWhenIngredientsAndInstructionsEmpty() {
        let recipe = Self.makeRecipe(id: 1)
        #expect(!recipe.hasDetail)
    }

    @Test func hasDetailTrueWhenIngredientsPresent() {
        let recipe = Self.makeRecipe(
            id: 1,
            ingredients: [RecipeIngredient(text: "1 cup flour")]
        )
        #expect(recipe.hasDetail)
    }

    @Test func hasDetailTrueWhenInstructionsPresent() {
        let recipe = Self.makeRecipe(
            id: 1,
            instructions: [RecipeInstruction(step: 1, text: "Preheat oven")]
        )
        #expect(recipe.hasDetail)
    }

    @Test func hasDetailTrueWhenArticleHasNonEmptyBody() {
        let recipe = Self.makeRecipe(
            id: 1,
            kind: .article,
            articleBodyHTML: "<p>Some article content</p>"
        )
        #expect(recipe.hasDetail)
    }

    @Test func hasDetailFalseWhenArticleHasNilBody() {
        let recipe = Self.makeRecipe(
            id: 1,
            kind: .article,
            articleBodyHTML: nil
        )
        #expect(!recipe.hasDetail)
    }

    @Test func hasDetailFalseWhenArticleHasEmptyStringBody() {
        let recipe = Self.makeRecipe(
            id: 1,
            kind: .article,
            articleBodyHTML: ""
        )
        #expect(!recipe.hasDetail)
    }

    @Test func hasDetailTrueWhenArticleHasIngredientsEdgeCase() {
        let recipe = Self.makeRecipe(
            id: 1,
            ingredients: [RecipeIngredient(text: "1 cup flour")],
            kind: .article
        )
        #expect(recipe.hasDetail)
    }

    @Test func hasDetailFalseWhenRecipeKindIgnoresArticleBodyHTML() {
        let recipe = Self.makeRecipe(
            id: 1,
            kind: .recipe,
            articleBodyHTML: "<p>This should be ignored</p>"
        )
        #expect(!recipe.hasDetail)
    }

    private static func makeRecipe(
        id: Int,
        ingredients: [RecipeIngredient] = [],
        instructions: [RecipeInstruction] = [],
        kind: PostKind = .recipe,
        articleBodyHTML: String? = nil
    ) -> Recipe {
        Recipe(
            id: id,
            slug: "skillet-corn",
            title: "Garlic Butter Skillet Corn",
            excerpt: "An easy side dish.",
            canonicalURL: baseURL,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            ingredients: ingredients,
            instructions: instructions,
            kind: kind,
            articleBodyHTML: articleBodyHTML
        )
    }
}

@Suite("RecipeListItem value type") struct RecipeListItemTests {

    @Test func codableRoundTrip() throws {
        let original = RecipeListItem(
            id: 99,
            title: "Skillet Apple Crisp",
            excerpt: "Warm and bubbly.",
            heroImage: URL(string: "https://example.com/img.jpg"),
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            totalTimeDisplay: "45 min"
        )
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RecipeListItem.self, from: encoded)
        #expect(decoded == original)
    }
}

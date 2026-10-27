import DODDomain
import Foundation
import Observation

/// DUT-1014 — the ingredient rows currently visible in Recipe Detail, so a
/// Siri "add that to my list" can resolve "that" / "the flour".
@MainActor
@Observable
public final class OnscreenIngredients {

    public static let shared = OnscreenIngredients()

    public struct Entry: Sendable, Hashable, Identifiable {
        public let id: UUID
        public let displayText: String
        public let recipeID: Int
        public let recipeTitle: String
        /// One-ingredient copy of the recipe whose ingredient text is `displayText`.
        public let recipe: Recipe
    }

    public private(set) var entries: [Entry] = []

    public init() {}

    public func appear(_ entry: Entry) {
        entries.removeAll { $0.id == entry.id }
        entries.append(entry)
    }

    public func disappear(id: UUID) {
        entries.removeAll { $0.id == id }
    }

    public func clear(recipeID: Int) {
        entries.removeAll { $0.recipeID == recipeID }
    }
}

extension OnscreenIngredients.Entry {
    /// Build an entry whose `recipe` is a copy of `recipe` with exactly one
    /// ingredient (same id, text `displayText`). Mirrors
    /// `RecipeDetailViewModel.scaledRecipe` in `RecipeDetailViewModel+ShoppingList.swift`.
    public static func make(recipe: Recipe, ingredient: RecipeIngredient, displayText: String) -> Self {
        let single = Recipe(
            id: recipe.id,
            slug: recipe.slug,
            title: recipe.title,
            excerpt: recipe.excerpt,
            canonicalURL: recipe.canonicalURL,
            heroImage: recipe.heroImage,
            heroImageLargeURL: recipe.heroImageLargeURL,
            categoryIDs: recipe.categoryIDs,
            publishedAt: recipe.publishedAt,
            ingredients: [RecipeIngredient(id: ingredient.id, text: displayText)],
            instructions: recipe.instructions,
            prepTime: recipe.prepTime,
            cookTime: recipe.cookTime,
            totalTime: recipe.totalTime,
            servings: recipe.servings,
            nutrition: recipe.nutrition,
            video: recipe.video,
            kind: recipe.kind,
            articleBodyHTML: recipe.articleBodyHTML,
            recipeCategory: recipe.recipeCategory,
            recipeCuisine: recipe.recipeCuisine,
            suitableForDiet: recipe.suitableForDiet,
            author: recipe.author
        )
        return Self(
            id: ingredient.id,
            displayText: displayText,
            recipeID: recipe.id,
            recipeTitle: recipe.title,
            recipe: single
        )
    }
}

import DODDomain
import DODIntelligence
import Foundation

extension RecipeDetailViewModel {

    /// DUT-1026 — UserDefaults key for the feature flag. Default OFF.
    static let llmRecipeFallbackEnabledKey = "llmRecipeFallbackEnabled"

    /// DUT-1026 — true only when a `.recipe`-kind Recipe has neither ingredients nor
    /// instructions (both heuristic tiers failed). Never true for a working parse.
    nonisolated static func needsLLMFallback(_ recipe: Recipe) -> Bool {
        recipe.kind == .recipe && recipe.ingredients.isEmpty && recipe.instructions.isEmpty
    }

    /// DUT-1026 — overlay model-extracted lists onto an empty recipe. Mirrors
    /// `recipe(fromCard:listItem:canonicalURL:)` (+Classify.swift): same id/slug/list
    /// fields, ingredients via `RecipeIngredient.list(from:)`, steps numbered from 1.
    nonisolated static func recipe(
        fromExtracted extracted: ExtractedRecipe,
        listItem: RecipeListItem,
        canonicalURL: URL
    ) -> Recipe {
        Recipe(
            id: listItem.id,
            slug: canonicalURL.lastPathComponent,
            title: listItem.title,
            excerpt: listItem.excerpt,
            canonicalURL: canonicalURL,
            heroImage: listItem.heroImage,
            heroImageLargeURL: nil,
            categoryIDs: listItem.categoryIDs ?? [],
            publishedAt: listItem.publishedAt,
            updatedAt: listItem.updatedAt,
            ingredients: RecipeIngredient.list(from: extracted.ingredients),
            instructions: extracted.instructions.enumerated().map { index, text in
                RecipeInstruction(step: index + 1, text: text)
            }
        )
    }
}

import DODDomain
import Foundation

// DUT-534 — the live "Add to Shopping List" seam, split into its own extension
// file so `RecipeDetailDependencies.swift` stays under the SwiftLint 400-line
// `file_length` cap (matches the `+Download` / `+Profile` / `+CommentsRatings`
// splits).

extension LiveRecipeDetailDependencies {

    /// Route the recipe to the App-wired `LiveShoppingListAppender` closure
    /// (`DODFeatureSaved`), which appends its ingredient rows to the App-Group
    /// Shopping List store. Recipe Detail's `recipe` is already fully loaded, so
    /// the appender's hydrate step is a no-op here. When the closure isn't wired
    /// (previews / terse tests) this reports `.couldntLoad` so the UI never
    /// claims a row landed when nothing was persisted.
    public func addToShoppingList(_ recipe: Recipe) async -> AddToShoppingListResult {
        guard let appendToShoppingList else { return .couldntLoad }
        return await appendToShoppingList(recipe)
    }
}

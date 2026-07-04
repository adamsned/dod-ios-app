import DODDomain
import DODFeatureSaved
import Foundation

// DUT-534 — the "Add to Shopping List from any recipe" composition, split out
// of `AppDependencies.swift` to keep that file under the SwiftLint 400-line
// `file_length` cap.

extension AppDependencies {

    /// The production ``ShoppingListAppender`` (DUT-534). Composes the same
    /// ingredient-hydration path the Saved-tab picker uses
    /// (``SavedDependencies/recipeWithIngredients(_:)`` via
    /// ``LiveSavedDependencies``) with the App-Group ``ShoppingListStore``, so a
    /// card / never-opened recipe gets fetched + parsed once and a Detail recipe
    /// (already loaded) skips the fetch. Backs the Recipe-Detail action.
    func shoppingListAppender() -> LiveShoppingListAppender {
        let saved = savedDependencies()
        return LiveShoppingListAppender(
            hydrate: { recipe in await saved.recipeWithIngredients(recipe) }
        )
    }
}

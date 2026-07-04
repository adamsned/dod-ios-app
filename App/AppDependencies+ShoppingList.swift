import DODDomain
import DODFeatureSaved
import DODFeatureSearch
import Foundation

// DUT-534 — the "Add to Shopping List from any recipe" composition, split out
// of `AppDependencies.swift` to keep that file under the SwiftLint 400-line
// `file_length` cap. DUT-534 Part 2 hosts the Search dependency factory here
// too, since it's now Shopping-List-wired (same append seam Detail + Feed use).

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

    /// DUT-534 Part 2 — Search's dependency graph, wired with the same App-Group
    /// Shopping List append seam Recipe Detail + Feed use. A Search hit is
    /// ingredient-empty, so the appender hydrates it before appending.
    func searchDependencies() -> some SearchDependencies {
        let appender = shoppingListAppender()
        return LiveSearchDependencies(
            client: restClient,
            store: store,
            monitor: networkMonitor,
            shoppingListAppend: { recipe in await appender.addToShoppingList(recipe) }
        )
    }
}

import DODDomain
import DODFeatureSaved
import DODFeatureSearch
import Foundation
import SwiftUI

// DUT-534 — the "Add to Shopping List from any recipe" composition, split out
// of `AppDependencies.swift` to keep that file under the SwiftLint 400-line
// `file_length` cap. DUT-534 Part 2 hosts the Search dependency factory here
// too, since it's now Shopping-List-wired (same append seam Detail + Feed use).

extension AppDependencies {

    /// DUT-535 — the ingredient-selection-sheet builder's type: given the tapped
    /// recipe + a result completion, return the `AnyView`-erased sheet.
    typealias AddToShoppingListSheetBuilder =
        (Recipe, @escaping (AddToShoppingListResult) -> Void) -> AnyView

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

    /// DUT-535 — the ingredient-selection-sheet builder handed to
    /// ``RecipeDetailView``. The sheet type (``AddToShoppingListSheet``) lives in
    /// `DODFeatureSaved`, which `DODFeatureRecipeDetail` must not import, so the
    /// App wires this `AnyView`-erased closure. It builds a sheet over the tapped
    /// recipe, routing the confirmed subset through the appender's
    /// ``ShoppingListAppender/addToShoppingList(rows:)`` and reporting the result
    /// back so Recipe Detail shows its "Added N ingredients" Snackbar. Detail's
    /// recipe already carries ingredients, so the candidate rows build without a
    /// fetch.
    @MainActor
    func addToShoppingListSheetBuilder() -> AddToShoppingListSheetBuilder {
        let appender = shoppingListAppender()
        return { recipe, onComplete in
            AnyView(
                AddToShoppingListSheet(
                    recipe: recipe,
                    appender: appender,
                    onComplete: onComplete
                )
            )
        }
    }
}

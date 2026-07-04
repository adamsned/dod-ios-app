import DODDomain
import Foundation

// DUT-534 — "Add to Shopping List from any recipe". The Recipe-Detail toolbar
// action. Split into its own extension file to keep `RecipeDetailViewModel.swift`
// under the SwiftLint 400-line `file_length` cap (matches the `+Download` /
// `+Servings` / `+CommentSubmit` splits).

extension RecipeDetailViewModel {

    /// Append the currently-loaded recipe's ingredients to the Shopping List,
    /// then surface a confirming Snackbar. Detail already carries a fully-loaded
    /// `recipe`, so no hydration is needed — the appender skips the fetch.
    ///
    /// - `.added(count:)` → "Added N ingredients to your Shopping List" with a
    ///   trailing **View** action (the view routes it to `dod://shopping-list`).
    /// - `.couldntLoad` (no recipe yet, or the append seam isn't wired) →
    ///   "Couldn't load ingredients — open the recipe to add." with no action.
    ///
    /// Wraps the existing snackbar machinery: setting `snackbarMessage` shows
    /// the toast, and `snackbarActionTitle` drives the optional button; the
    /// view's `.task` auto-dismisses both after a few seconds (DUT-419).
    public func addToShoppingList() async {
        guard let recipe else {
            showAddToShoppingListSnackbar(for: .couldntLoad)
            return
        }
        let result = await dependencies.addToShoppingList(recipe)
        showAddToShoppingListSnackbar(for: result)
    }

    /// Map an ``AddToShoppingListResult`` onto the Snackbar copy + optional
    /// action. Pure state mutation — the view renders it. DUT-535 — `internal`
    /// (was `private`) so ``RecipeDetailView`` calls it from the selection
    /// sheet's completion after the chosen subset is appended.
    func showAddToShoppingListSnackbar(for result: AddToShoppingListResult) {
        switch result {
        case .added(let count):
            snackbarMessage = Self.addedMessage(count: count)
            snackbarActionTitle = "View"
        case .couldntLoad:
            snackbarMessage = "Couldn't load ingredients — open the recipe to add."
            snackbarActionTitle = nil
        }
    }

    /// "Added N ingredient(s) to your Shopping List" — singular/plural aware.
    /// `nonisolated static` + pure so it's unit-testable without the view model.
    nonisolated static func addedMessage(count: Int) -> String {
        let noun = count == 1 ? "ingredient" : "ingredients"
        return "Added \(count) \(noun) to your Shopping List"
    }
}

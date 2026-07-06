import DODDomain
import Foundation

// DUT-534 Part 2 — "Add to Shopping List" from a Feed card's long-press menu.
// Split into its own extension file to keep `FeedViewModel.swift` under the
// SwiftLint 400-line `file_length` cap (mirrors Recipe Detail's
// `RecipeDetailViewModel+ShoppingList.swift`).

extension FeedViewModel {

    /// Append a card's recipe ingredients to the Shopping List, then surface a
    /// confirming snackbar. A card carries a lightweight `RecipeListItem` with no
    /// ingredients, so we hand the shared appender a minimal `Recipe` built from
    /// it (`Recipe(listItem:)`); the appender's hydrate-if-needed step fetches +
    /// parses the ingredients the same way Recipe Detail / the Saved picker do.
    ///
    /// - `.added(count:)` → "Added N ingredients to your Shopping List" with a
    ///   trailing **View** action (the view routes it to `dod://shopping-list`).
    /// - `.couldntLoad` (offline / unfetchable / no ingredients) → the fallback
    ///   "Couldn't load ingredients. Open the recipe to add." with no action.
    public func addToShoppingList(_ item: RecipeListItem) async {
        // DUT-541 in-flight guard: a rapid double long-press fires two
        // independent Tasks; skip the second concurrent add of the SAME recipe
        // while one is still in flight (the appender's append is additive by
        // CL-77, so a concurrent duplicate would double-stack the ingredients).
        // A deliberate re-add AFTER this one completes is still allowed.
        guard !addingIDs.contains(item.id) else { return }
        addingIDs.insert(item.id)
        defer { addingIDs.remove(item.id) }

        let result = await dependencies.addToShoppingList(Recipe(listItem: item))
        showShoppingListSnackbar(for: result)
    }

    /// Map an ``AddToShoppingListResult`` onto the snackbar copy + optional
    /// action. Pure state mutation — the view renders it.
    private func showShoppingListSnackbar(for result: AddToShoppingListResult) {
        switch result {
        case .added(let count):
            shoppingListSnackbarMessage = Self.shoppingListAddedMessage(count: count)
            shoppingListSnackbarActionTitle = "View"
        case .couldntLoad:
            shoppingListSnackbarMessage = "Couldn't load ingredients. Open the recipe to add."
            shoppingListSnackbarActionTitle = nil
        }
    }

    /// Dismiss the Shopping List snackbar (auto-dismiss timer, or a tapped
    /// **View** action). Clears the trailing action too.
    public func dismissShoppingListSnackbar() {
        shoppingListSnackbarMessage = nil
        shoppingListSnackbarActionTitle = nil
    }

    /// "Added N ingredient(s) to your Shopping List" — singular/plural aware.
    /// Copy is byte-identical to Recipe Detail's Part 1 snackbar. `nonisolated
    /// static` + pure so it's unit-testable without the view model.
    nonisolated static func shoppingListAddedMessage(count: Int) -> String {
        let noun = count == 1 ? "ingredient" : "ingredients"
        return "Added \(count) \(noun) to your Shopping List"
    }
}

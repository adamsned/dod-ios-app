import Foundation

/// Outcome of appending one recipe's ingredients to the Shopping List
/// (DUT-534 — "Add to Shopping List from any recipe").
///
/// Lives in `DODDomain` (the shared leaf every feature package already
/// imports) so the surfaces that trigger the append — Recipe Detail and the
/// Feed/Search cards — can name the result WITHOUT importing `DODFeatureSaved`
/// (where the appender + the App-Group store live). The App composition root
/// wires each feature's `addToShoppingList` closure to the live appender, and
/// the shared affordance branches on this enum to pick its Snackbar copy.
public enum AddToShoppingListResult: Sendable, Equatable {

    /// The recipe's ingredients were appended — `count` rows were added. The
    /// affordance shows "Added N ingredients to your Shopping List" with a
    /// **View** action that opens the list. `count` is the number of appended
    /// rows (per-recipe, un-merged — CL-77), so a recipe with N ingredient
    /// lines yields `.added(count: N)`.
    case added(count: Int)

    /// The recipe carried no ingredients and none could be fetched (offline /
    /// unfetchable / parse failure), so nothing was added. The affordance shows
    /// "Couldn't load ingredients — open the recipe to add." Distinct from
    /// `.added(count: 0)`, which would only arise from a genuinely empty
    /// hydrated recipe (still nothing to add, folded into this case by the
    /// appender so the UI copy is consistent).
    case couldntLoad
}

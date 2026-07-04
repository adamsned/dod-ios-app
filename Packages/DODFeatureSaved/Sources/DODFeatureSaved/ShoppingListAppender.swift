import DODDomain
import Foundation

/// Appends a single recipe's ingredients to the persisted Shopping List, from
/// anywhere in the app (DUT-534 — "Add to Shopping List from any recipe, not
/// just saved").
///
/// **Why a seam.** Before DUT-534 the only way onto the list was the Saved-tab
/// picker (``ShoppingListBuilderSheet`` → ``ShoppingListViewModel/add(recipes:)``).
/// Recipe Detail and the Feed/Search cards want the same one-tap append, but
/// they don't host a ``ShoppingListViewModel`` and (crucially) their feature
/// packages don't — and shouldn't — depend on `DODFeatureSaved`. So the append
/// logic lives behind this protocol here, and each surface receives a thin
/// `(Recipe) async -> AddToShoppingListResult` closure wired to the live impl by
/// the App composition root. The result type lives in `DODDomain` so the
/// calling surfaces name it without importing `DODFeatureSaved`.
///
/// The append writes straight to the App-Group ``ShoppingListStore`` via its
/// atomic ``ShoppingListStore/append(rows:)`` — so a Saved-tab
/// ``ShoppingListViewModel`` that's open reloads the new rows on its next
/// appear (DUT-534 reload-on-appear guard), and the widget/control read the
/// same store.
@MainActor
public protocol ShoppingListAppender: Sendable {

    /// Add `recipe`'s ingredients to the Shopping List.
    ///
    /// - Hydrate-if-needed: an empty-ingredients recipe (a Feed/Search card, or
    ///   a never-opened saved recipe) is fetched through the hydration seam
    ///   first; a recipe that already carries ingredients (Recipe Detail) skips
    ///   the fetch.
    /// - Returns ``AddToShoppingListResult/added(count:)`` with the number of
    ///   appended rows, or ``AddToShoppingListResult/couldntLoad`` when the
    ///   recipe has no ingredients and none could be fetched.
    func addToShoppingList(_ recipe: Recipe) async -> AddToShoppingListResult

    /// DUT-535 — append a caller-chosen SUBSET of pre-built ingredient rows to
    /// the Shopping List (the ingredient-selection sheet path).
    ///
    /// Unlike ``addToShoppingList(_:)``, which explodes + classifies a whole
    /// recipe, this appends `rows` verbatim — the ``AddToShoppingListSheet`` has
    /// already built the candidate rows via ``ShoppingListViewModel/rows(from:)``
    /// and the user has deselected some. No hydration (the rows already carry
    /// their ingredient text + aisle), no re-classification, no merge (CL-77 —
    /// appended AS-IS, consistent with ``addToShoppingList(_:)``).
    ///
    /// - Returns ``AddToShoppingListResult/added(count:)`` with `rows.count`, or
    ///   ``AddToShoppingListResult/couldntLoad`` when `rows` is empty or no
    ///   App-Group store is available (never a false "added").
    func addToShoppingList(rows: [ShoppingListViewModel.Item]) async -> AddToShoppingListResult
}

/// The production ``ShoppingListAppender`` (DUT-534).
///
/// Composes the two existing seams rather than re-implementing either:
/// - **Hydration** via an injected `hydrate` closure — the App target passes
///   the same `recipeWithIngredients` path the Saved picker uses
///   (``SavedDependencies/recipeWithIngredients(_:)``), so a never-opened /
///   list-only recipe gets fetched + parsed + cached exactly once, the same
///   way (DUT-487).
/// - **Row building** via ``ShoppingListViewModel/rows(from:)`` (the shared
///   explode-and-classify used by the initial build + `add(recipes:)`), so a
///   card-appended row is byte-identical to a picker-built one (CL-77).
/// - **Persistence** via ``ShoppingListStore/append(rows:)`` (atomic load →
///   append → save, preserving checked / already-have).
public struct LiveShoppingListAppender: ShoppingListAppender {

    /// Hydrate a recipe's `ingredients` when empty. Identity by default (used
    /// by the Recipe-Detail path, where the recipe is already loaded, so the
    /// closure is never actually invoked — the `guard` below short-circuits).
    private let hydrate: @Sendable (Recipe) async -> Recipe

    /// The App-Group Shopping List store. Optional so a no-App-Group
    /// environment (unlikely in production, but possible in tests/previews)
    /// degrades to a `.couldntLoad` rather than crashing — mirrors
    /// ``ShoppingListViewModel``'s `store: nil` in-memory fallback.
    private let store: ShoppingListStore?

    /// - Parameters:
    ///   - hydrate: fills a recipe's ingredients when empty (the DUT-487
    ///     fetch+parse+cache path). Defaults to identity so a caller that only
    ///     ever passes already-loaded recipes (Recipe Detail) can omit it.
    ///   - store: the App-Group Shopping List store. Defaults to the real one;
    ///     pass a test-scoped store (or `nil`) in tests.
    public init(
        hydrate: @escaping @Sendable (Recipe) async -> Recipe = { $0 },
        store: ShoppingListStore? = ShoppingListStore()
    ) {
        self.hydrate = hydrate
        self.store = store
    }

    public func addToShoppingList(_ recipe: Recipe) async -> AddToShoppingListResult {
        // Hydrate-if-needed: Detail arrives populated (skip the fetch); a card /
        // never-opened saved recipe arrives empty and gets fetched once.
        let resolved = recipe.ingredients.isEmpty ? await hydrate(recipe) : recipe

        // Still empty after hydration (offline / unfetchable / parse failure)
        // → nothing to add. Folded into `.couldntLoad` so the surface shows the
        // "open the recipe to add" copy rather than a misleading "Added 0".
        let rows = ShoppingListViewModel.rows(from: [resolved])
        guard !rows.isEmpty else { return .couldntLoad }

        // No store (no App Group) → can't persist; report couldn't-load so the
        // user isn't told the row landed when it didn't.
        guard let store else { return .couldntLoad }

        store.append(rows: rows)
        return .added(count: rows.count)
    }

    /// DUT-535 — append a caller-selected subset of pre-built rows. The sheet
    /// built the candidates through ``ShoppingListViewModel/rows(from:)`` (same
    /// explode-and-classify as the whole-recipe path), so here we only persist
    /// the chosen rows — no hydrate, no re-classify. An empty selection (all
    /// deselected, which the sheet's disabled-at-zero confirm normally prevents)
    /// or a missing store reports `.couldntLoad` rather than a false "added 0".
    public func addToShoppingList(rows: [ShoppingListViewModel.Item]) async -> AddToShoppingListResult {
        guard !rows.isEmpty else { return .couldntLoad }
        guard let store else { return .couldntLoad }
        store.append(rows: rows)
        return .added(count: rows.count)
    }
}

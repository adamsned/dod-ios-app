import DODDomain
import DODSupport
import Foundation
import Observation

/// Backs ``ShoppingListView`` — the aisle-grouped shopping-list surface.
///
/// Spec trace: US-39 / AC-39.4 (aisle grouping + store-walk order), AC-39.5
/// (the per-row check toggle), AC-39.1 (empty state), AC-39.11 (VoiceOver row
/// labels). CL-82 (this UI-slice scope: per-recipe rows — NOT aggregated, per
/// CL-70/CL-77; ephemeral check + already-have state; mock-data-driven; lands
/// in `DODFeatureSaved` ahead of the `DODFeatureShoppingList` extraction).
/// CL-80 (groups by the six-case `IngredientAisleClassifier.Aisle` shipped by
/// T-680a; the nine-case render set + the `DODDomain` hoist are a T-680c/T-681
/// mechanical reconciliation).
///
/// **Per-recipe rows, no merge (CL-70 / CL-77 / CL-82):** three recipes that
/// each call for "yellow onion, diced" produce three separate ``Item`` rows,
/// each carrying its source-recipe title. The ``IngredientAggregator``
/// same-unit summation (T-680a) is an available-but-not-default capability and
/// is intentionally NOT wired here.
///
/// **Ephemeral state (CL-82):** ``checkedIDs`` and ``alreadyHaveIDs`` live in
/// memory and reset on re-init — T-680b ships no persistence. T-680c swaps the
/// sets for the SwiftData `isChecked` round-trip (AC-39.8) with no change to
/// the view's binding shape.
@Observable
@MainActor
public final class ShoppingListViewModel {

    /// One shopping-list row. Identity is per-row (NOT per-ingredient-name) so
    /// duplicate ingredients from different recipes stay distinct (CL-77).
    public struct Item: Identifiable, Equatable, Sendable, Codable {
        public let id: UUID
        /// The raw ingredient line (e.g. `"2 cups diced yellow onion"`).
        public let ingredientText: String
        /// The source recipe's title — the AC-39.2 sub-label.
        public let recipeTitle: String
        /// The classified store aisle (from ``IngredientAisleClassifier``).
        public let aisle: IngredientAisleClassifier.Aisle

        public init(
            id: UUID = UUID(),
            ingredientText: String,
            recipeTitle: String,
            aisle: IngredientAisleClassifier.Aisle
        ) {
            self.id = id
            self.ingredientText = ingredientText
            self.recipeTitle = recipeTitle
            self.aisle = aisle
        }
    }

    /// One rendered aisle section: the aisle + its rows, in input order.
    public struct Section: Identifiable, Equatable, Sendable {
        public var id: IngredientAisleClassifier.Aisle { aisle }
        public let aisle: IngredientAisleClassifier.Aisle
        public let items: [Item]
    }

    /// Every row in the list, in insertion order (per-recipe, un-merged).
    public private(set) var items: [Item]

    /// Rows the user has checked off while shopping (AC-39.5). Ephemeral.
    public private(set) var checkedIDs: Set<UUID> = []

    /// Rows the user marked "I already have this" — removed from the still-need
    /// list (CL-82 / DUT-488 — now persisted, no longer ephemeral).
    public private(set) var alreadyHaveIDs: Set<UUID> = []

    /// Backing persistence for the list (DUT-488). `nil` for the mock / preview
    /// inits and for any environment where the App Group suite can't be opened —
    /// in that case the list is in-memory-only exactly as it was under CL-82.
    private let store: ShoppingListStore?

    /// Designated init (DUT-488). Sets the list to the given `items` AS-IS — it
    /// does NOT auto-load from `store`, and does NOT persist on construction.
    /// This keeps the explicit-data inits (`init(items:)` via tests/mocks,
    /// `init(recipes:)`) from being clobbered BY — or clobbering — whatever is
    /// saved. Only the no-arg ``init(store:)`` path (the production entry via
    /// ``ShoppingListView`` / ``SavedView``) auto-loads persisted state, and
    /// only the mutations (`add` / `toggleChecked` / `markAlreadyHave` /
    /// `clearAll`) write it back. `store` is held so those mutations persist.
    ///
    /// - Parameters:
    ///   - items: The rows to seed the list with (explicit, authoritative).
    ///   - store: Where later mutations persist to. Defaults to the real
    ///     App-Group store; pass `nil` (mock/preview/tests) to stay in memory.
    public init(items: [Item], store: ShoppingListStore? = ShoppingListStore()) {
        self.store = store
        self.items = items
    }

    /// The production Shopping List entry point (used by ``ShoppingListView`` /
    /// ``SavedView``). Auto-loads persisted state (DUT-488): if `store` has a
    /// saved snapshot, `items` / `checkedIDs` / `alreadyHaveIDs` are restored
    /// from it so opening the list shows exactly what the cook last saw; with no
    /// saved list it starts empty-first (DUT-487 / T-906). Explicit-data inits
    /// deliberately do NOT take this path — see ``init(items:store:)``.
    public init(store: ShoppingListStore? = ShoppingListStore()) {
        self.store = store
        if let snapshot = store?.load() {
            self.items = snapshot.items
            self.checkedIDs = Set(snapshot.checkedIDs)
            self.alreadyHaveIDs = Set(snapshot.alreadyHaveIDs)
        } else {
            self.items = []
        }
    }

    // MARK: - Derived render model

    /// `true` when there are no still-need rows to show (drives AC-39.1's
    /// empty state). A list whose every row was marked "already have" is also
    /// empty for render purposes.
    public var isEmpty: Bool {
        visibleItems.isEmpty
    }

    /// Rows still on the list — everything not marked "already have". Checked
    /// rows stay visible (struck through), only already-have rows drop out.
    public var visibleItems: [Item] {
        items.filter { !alreadyHaveIDs.contains($0.id) }
    }

    /// Count of still-need rows (the list badge / "N items" surfaces).
    public var remainingCount: Int {
        visibleItems.count
    }

    /// Count of still-need rows the user has NOT yet checked off.
    public var uncheckedCount: Int {
        visibleItems.filter { !checkedIDs.contains($0.id) }.count
    }

    /// The visible rows grouped into aisle sections in store-walk order
    /// (`Aisle.allCases` declaration order — Produce → Meat → Dairy → Pantry →
    /// Spices → Other), omitting any aisle with zero visible rows (AC-39.4).
    public var sections: [Section] {
        let grouped = Dictionary(grouping: visibleItems, by: \.aisle)
        return IngredientAisleClassifier.Aisle.allCases.compactMap { aisle in
            guard let rows = grouped[aisle], !rows.isEmpty else { return nil }
            return Section(aisle: aisle, items: rows)
        }
    }

    // MARK: - Mutations (persisted — DUT-488)

    public func isChecked(_ item: Item) -> Bool {
        checkedIDs.contains(item.id)
    }

    /// Flip the AC-39.5 check state for a row (applies the strikethrough).
    /// Persists so the checked state survives close/reopen (DUT-488).
    public func toggleChecked(_ item: Item) {
        if checkedIDs.contains(item.id) {
            checkedIDs.remove(item.id)
        } else {
            checkedIDs.insert(item.id)
        }
        persist()
    }

    /// Mark a row "I already have this" — it drops out of the still-need list
    /// (CL-82). Also clears any check state for the row so re-adding it later
    /// (T-680c) starts clean. Persists (DUT-488).
    public func markAlreadyHave(_ item: Item) {
        alreadyHaveIDs.insert(item.id)
        checkedIDs.remove(item.id)
        persist()
    }

    /// Append more recipes' ingredients to the list in place (DUT-487 / T-906).
    /// Explodes + classifies each recipe's ingredients into per-recipe rows and
    /// appends them, keeping every existing row. No de-dup — per-recipe rows are
    /// intentional (CL-77), so adding a recipe already on the list stacks its
    /// rows again. Backs the "Add recipes" affordance on the populated list.
    /// Persists (DUT-488).
    public func add(recipes: [Recipe]) {
        items.append(contentsOf: Self.rows(from: recipes))
        persist()
    }

    /// Empty the list entirely — clears rows + checked + already-have state,
    /// then persists so a saved list is genuinely emptyable and stays empty
    /// across close/reopen (DUT-488). Backs the "Clear list" toolbar affordance.
    public func clearAll() {
        items.removeAll()
        checkedIDs.removeAll()
        alreadyHaveIDs.removeAll()
        persist()
    }

    /// Save the current list state to ``store`` (DUT-488). No-op when `store` is
    /// nil (mock / preview / no App Group), and never throws — see
    /// ``ShoppingListStore``.
    private func persist() {
        store?.save(items: items, checked: checkedIDs, alreadyHave: alreadyHaveIDs)
    }
}

// MARK: - Construction from recipes

extension ShoppingListViewModel {

    /// Build a view-model from recipes, exploding each recipe's ingredients
    /// into per-recipe rows classified by ``IngredientAisleClassifier``
    /// (CL-77 — no cross-recipe merge). This is the shape T-680c's production
    /// initializer reuses once the entry surfaces feed real recipes in. Takes
    /// the exploded rows AS-IS through ``init(items:store:)`` (DUT-488) — it is
    /// NOT auto-loaded, so an explicit recipe build is never clobbered by a
    /// saved list. `store` defaults to the real App-Group store; pass `nil` to
    /// build in memory only.
    public convenience init(recipes: [Recipe], store: ShoppingListStore? = ShoppingListStore()) {
        self.init(items: Self.rows(from: recipes), store: store)
    }

    /// Explode `recipes` into per-recipe ``Item`` rows, each classified through
    /// ``IngredientAisleClassifier`` (CL-77 — no cross-recipe merge). Shared by
    /// ``init(recipes:)`` and ``add(recipes:)`` (DUT-487 / T-906) so the initial
    /// build and later appends produce identical rows.
    private static func rows(from recipes: [Recipe]) -> [Item] {
        recipes.flatMap { recipe in
            recipe.ingredients.map { ingredient in
                Item(
                    ingredientText: ingredient.text,
                    recipeTitle: recipe.title,
                    aisle: IngredientAisleClassifier.classify(ingredient.text)
                )
            }
        }
    }
}

// MARK: - Mock fixture (CL-82 — drives the view ahead of the entry surfaces)

extension ShoppingListViewModel {

    /// Three recipes' worth of ingredient lines, classified through the live
    /// ``IngredientAisleClassifier``, so ``ShoppingListView`` is self-contained
    /// and previewable ahead of T-680c's entry wiring. The fixture deliberately
    /// includes a duplicate ("yellow onion" in two recipes) to demonstrate the
    /// per-recipe-row behavior (CL-77) and at least one `.other`-bucket line.
    /// Passes `store: nil` (DUT-488) so previews / snapshot fixtures never read
    /// or write the real App Group suite — the mock stays a pure in-memory list.
    public static var mock: ShoppingListViewModel {
        ShoppingListViewModel(items: mockItems, store: nil)
    }

    /// The mock rows as plain values (so tests can assert against them without
    /// reaching through the `@Observable` instance).
    public static var mockItems: [Item] {
        func rows(_ recipe: String, _ lines: [String]) -> [Item] {
            lines.map { line in
                Item(
                    ingredientText: line,
                    recipeTitle: recipe,
                    aisle: IngredientAisleClassifier.classify(line)
                )
            }
        }
        return rows(
            "Dutch Oven Pot Roast",
            [
                "3 lb beef chuck roast",
                "1 yellow onion, quartered",
                "4 carrots, peeled",
                "3 cloves garlic, minced",
                "2 cups beef broth",
                "1 tsp salt",
            ]
        )
            + rows(
                "Skillet Chicken Tacos",
                [
                    "1 lb chicken thighs",
                    "1 yellow onion, diced",
                    "2 limes",
                    "1 cup shredded cheddar",
                    "1 tsp cumin",
                    "8 corn tortillas",
                ]
            )
            + rows(
                "Weeknight Veggie Pasta",
                [
                    "12 oz pasta",
                    "2 zucchini, sliced",
                    "1 cup heavy cream",
                    "½ cup parmesan",
                    "2 tbsp olive oil",
                    "black pepper to taste",
                ]
            )
    }
}

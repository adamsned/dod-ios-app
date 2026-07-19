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

        private enum CodingKeys: String, CodingKey {
            case id, ingredientText, recipeTitle, aisle
        }

        /// Defensive decode (DUT-590). The `aisle` enum is stored raw inside
        /// each persisted row, and ``ShoppingListStore/load()`` treats ANY
        /// decode failure as "no saved list" (`try?` → nil). If a future release
        /// renames/removes an ``IngredientAisleClassifier/Aisle`` case, every
        /// existing row carrying that raw value would fail to decode and the
        /// WHOLE snapshot would silently vanish. Decoding the raw String and
        /// falling back to `.other` on an unknown/removed case contains the blast
        /// radius to that one row, so a single bad case can't nuke the list.
        /// This lives in DODFeatureSaved's Codable layer only — the `Aisle` enum
        /// itself is unchanged. (The `dod.shoppingList.v1` store key stays; any
        /// genuinely incompatible wire change still bumps to `vN`.)
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.id = try container.decode(UUID.self, forKey: .id)
            self.ingredientText = try container.decode(String.self, forKey: .ingredientText)
            self.recipeTitle = try container.decode(String.self, forKey: .recipeTitle)
            let rawAisle = try container.decode(String.self, forKey: .aisle)
            self.aisle = IngredientAisleClassifier.Aisle(rawValue: rawAisle) ?? .other
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

    /// The `UserDefaults` the shared "Use Metric Units" preference
    /// (``IngredientMetricConverter/preferenceKey``) is read from by
    /// ``add(recipes:)``. Defaults to `.standard` — the same store
    /// `SettingsViewModel` writes through — so a bulk-built list picks up
    /// whatever the preference is set to AT APPEND TIME. Constructor-injected
    /// so tests use an isolated suite instead of touching `.standard`.
    private let defaults: UserDefaults

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
    ///   - defaults: where the "Use Metric Units" preference is read from by
    ///     a later ``add(recipes:)`` call. Defaults to `.standard`; pass a
    ///     test-scoped suite in tests.
    public init(
        items: [Item],
        store: ShoppingListStore? = ShoppingListStore(),
        defaults: UserDefaults = .standard
    ) {
        self.store = store
        self.defaults = defaults
        self.items = items
        rebuildVisibleItems()
    }

    /// The production Shopping List entry point (used by ``ShoppingListView`` /
    /// ``SavedView``). Auto-loads persisted state (DUT-488): if `store` has a
    /// saved snapshot, `items` / `checkedIDs` / `alreadyHaveIDs` are restored
    /// from it so opening the list shows exactly what the cook last saw; with no
    /// saved list it starts empty-first (DUT-487 / T-906). Explicit-data inits
    /// deliberately do NOT take this path — see ``init(items:store:)``.
    public init(store: ShoppingListStore? = ShoppingListStore(), defaults: UserDefaults = .standard) {
        self.store = store
        self.defaults = defaults
        if let snapshot = store?.load() {
            self.items = snapshot.items
            self.checkedIDs = Set(snapshot.checkedIDs)
            self.alreadyHaveIDs = Set(snapshot.alreadyHaveIDs)
        } else {
            self.items = []
        }
        purgeMaskedRows()
        rebuildVisibleItems()
    }

    /// DUT-534 — re-read the persisted snapshot so an EXTERNAL append (a
    /// "Add to Shopping List" from Recipe Detail or a Feed/Search card, which
    /// writes straight to ``ShoppingListStore`` via
    /// ``ShoppingListStore/append(rows:)``) surfaces when the cook returns to
    /// the list. ``ShoppingListView`` calls this on appear.
    ///
    /// **Lost-update guard.** Without this the VM keeps its init-time in-memory
    /// snapshot; a later in-list mutation (`toggleChecked` / `markAlreadyHave` /
    /// `clearAll`) persists that stale snapshot and CLOBBERS the external
    /// append. Reloading first re-seats `items` / `checkedIDs` /
    /// `alreadyHaveIDs` to the store's current state, so the next mutation
    /// persists the MERGED set (existing rows + the external append), not a
    /// stale one.
    ///
    /// No-op when `store` is nil (mock / preview / in-memory tests) — there's
    /// nothing external to reconcile against. A store that has never been
    /// written (``ShoppingListStore/load()`` returns nil) is left as-is rather
    /// than blanked, so a freshly built in-memory list isn't wiped by an appear.
    public func reloadFromStore() {
        guard let snapshot = store?.load() else { return }
        items = snapshot.items
        checkedIDs = Set(snapshot.checkedIDs)
        alreadyHaveIDs = Set(snapshot.alreadyHaveIDs)
        purgeMaskedRows()
        rebuildVisibleItems()
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
    ///
    /// **Cached (perf).** Formerly a computed property that re-ran
    /// `items.filter { !alreadyHaveIDs.contains($0.id) }` on EVERY access, and a
    /// single render reads several derived surfaces off it (`isEmpty`,
    /// `remainingCount`, `uncheckedCount`, `sections`) — so the same filter ran
    /// 4-5× per render. It is now recomputed once, only when `items` /
    /// `alreadyHaveIDs` actually change (see ``rebuildVisibleItems()``), and the
    /// derived surfaces read this stored array. Behavior is identical.
    public private(set) var visibleItems: [Item] = []

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

    /// Recompute the cached ``visibleItems``. Called from every path that
    /// mutates `items` or `alreadyHaveIDs` (the inits, `reloadFromStore`, `add`,
    /// `markAlreadyHave`, `clearAll`) so the one filter runs on change instead of
    /// per-access. `toggleChecked` is deliberately NOT a caller — it touches only
    /// `checkedIDs`, which doesn't affect which rows are visible.
    private func rebuildVisibleItems() {
        visibleItems = items.filter { !alreadyHaveIDs.contains($0.id) }
    }

    /// Clean up legacy "already have" rows from a PRE-DUT-589 persisted snapshot.
    /// Current builds REMOVE an already-have row from `items` outright (see
    /// ``markAlreadyHave(_:)``), so `alreadyHaveIDs` is normally empty and this is
    /// a no-op. But an OLD blob could still carry masked rows: rows left in
    /// `items` with their ids in `alreadyHaveIDs`. Those are invisible (filtered
    /// out of ``visibleItems``) yet still counted by ``add(recipes:)``'s de-dup
    /// against the FULL `items` — so a masked "1 onion" from Recipe A silently
    /// SUPPRESSES a genuine re-add of that same line. Dropping the masked rows and
    /// clearing the set on load makes `items` match the visible list again, so
    /// re-adds surface. Only called on the load paths (`init(store:)` /
    /// `reloadFromStore`).
    private func purgeMaskedRows() {
        guard !alreadyHaveIDs.isEmpty else { return }
        items.removeAll { alreadyHaveIDs.contains($0.id) }
        alreadyHaveIDs.removeAll()
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
    /// (CL-82). The row is REMOVED from `items` outright (DUT-589) rather than
    /// merely masked by `alreadyHaveIDs`, so the persisted App-Group blob shrinks
    /// with it instead of growing without bound; its id is also purged from both
    /// ephemeral sets so no parallel bookkeeping lingers. The trailing-swipe UX
    /// (ShoppingListView) is unchanged — the row still disappears from the list,
    /// and every other row's checked state survives (only this row's state is
    /// dropped). Persists (DUT-488).
    public func markAlreadyHave(_ item: Item) {
        items.removeAll { $0.id == item.id }
        alreadyHaveIDs.remove(item.id)
        checkedIDs.remove(item.id)
        rebuildVisibleItems()
        persist()
    }

    /// Append more recipes' ingredients to the list in place (DUT-487 / T-906).
    /// Explodes + classifies each recipe's ingredients into per-recipe rows and
    /// appends them, keeping every existing row.
    ///
    /// De-dup (DUT-589 / DUT-648): a row is skipped only when the same recipe
    /// already contributed the same line the same number of times — so a
    /// whole-recipe re-add no longer re-stacks rows, distinct recipes sharing an
    /// ingredient still keep separate rows, AND a recipe that legitimately
    /// repeats a line keeps BOTH (see ``dedupedAppend(existing:adding:)``).
    ///
    /// Metric preference — this is the Saved-tab "Make Shopping List" bulk
    /// picker (``ShoppingListBuilderSheet`` → ``ShoppingListView``'s
    /// `build(from:)`), a sibling of the single-recipe "Add to Shopping List"
    /// append that ``LiveShoppingListAppender`` backs from Recipe Detail / a
    /// Feed / Search card. That appender rewrites appended rows to metric when
    /// the shared "Use Metric Units" preference is on; this path built rows
    /// straight from ``rows(from:)`` with no such rewrite, so a metric-mode
    /// cook who built their list here got imperial rows possibly mixed onto a
    /// list that already carried metric rows added from Recipe Detail — the
    /// same toggle behaving differently depending on which surface the append
    /// came from. Applying ``applyMetricPreference(_:defaults:)`` here closes
    /// that gap. Persists.
    public func add(recipes: [Recipe]) {
        let newRows = Self.applyMetricPreference(Self.rows(from: recipes), defaults: defaults)
        items = Self.dedupedAppend(existing: items, adding: newRows)
        rebuildVisibleItems()
        persist()
    }

    /// Empty the list entirely — clears rows + checked + already-have state,
    /// then persists so a saved list is genuinely emptyable and stays empty
    /// across close/reopen (DUT-488). Backs the "Clear list" toolbar affordance.
    public func clearAll() {
        items.removeAll()
        checkedIDs.removeAll()
        alreadyHaveIDs.removeAll()
        rebuildVisibleItems()
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
    public convenience init(
        recipes: [Recipe],
        store: ShoppingListStore? = ShoppingListStore(),
        defaults: UserDefaults = .standard
    ) {
        self.init(
            items: Self.applyMetricPreference(Self.rows(from: recipes), defaults: defaults),
            store: store,
            defaults: defaults
        )
    }

    /// Explode `recipes` into per-recipe ``Item`` rows, each classified through
    /// ``IngredientAisleClassifier`` (CL-77 — no cross-recipe merge). Shared by
    /// ``init(recipes:)`` and ``add(recipes:)`` (DUT-487 / T-906) so the initial
    /// build and later appends produce identical rows. DUT-534 — module-internal
    /// (was `private`) so ``LiveShoppingListAppender`` builds the exact same rows
    /// when appending from Recipe Detail / a card, rather than duplicating the
    /// explode-and-classify logic.
    static func rows(from recipes: [Recipe]) -> [Item] {
        recipes.flatMap { recipe in
            recipe.ingredients.compactMap { ingredient -> Item? in
                // Defense-in-depth (DUT-587): drop any ingredient whose text
                // trims to empty so a blank/whitespace line — even one that
                // slips past the parser — never becomes a garbage row.
                guard
                    !ingredient.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                else {
                    return nil
                }
                return Item(
                    ingredientText: ingredient.text,
                    recipeTitle: recipe.title,
                    aisle: IngredientAisleClassifier.classify(ingredient.text)
                )
            }
        }
    }

    // DUT-648: the append de-dup (`dedupedAppend` / `occurrenceKeys` / `RowKey`)
    // lives in `ShoppingListViewModel+Dedup.swift`; the metric-preference
    // rewrite (`applyMetricPreference`) lives in
    // `ShoppingListViewModel+MetricPreference.swift`; the CL-82 mock fixture
    // lives in `ShoppingListViewModel+Mock.swift` — all to keep this file under
    // SwiftLint's `file_length` cap.
}

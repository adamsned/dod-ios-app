import DODDomain
import Foundation
import Testing

@testable import DODFeatureSaved

/// L1 coverage for DUT-534 — "Add to Shopping List from any recipe". Exercises
/// the ``LiveShoppingListAppender`` seam, the atomic
/// ``ShoppingListStore/append(rows:)``, and the reload-on-appear lost-update
/// guard, all against a test-scoped `UserDefaults` store + a fake hydrate
/// closure (no App Group, no network).
@MainActor
@Suite("Add to Shopping List appender (DUT-534)")
struct ShoppingListAppenderTests {

    // MARK: - Appender: hydrate-if-needed + count

    /// A recipe that ALREADY has ingredients skips the fetch and appends its
    /// rows; the result reports the exact count.
    @Test func populatedRecipeAppendsWithoutHydrating() async {
        let store = Self.freshStore()
        let hydrate = SpyHydrate()
        let appender = LiveShoppingListAppender(hydrate: hydrate.call, store: store)

        let recipe = Self.recipe(id: 1, ingredients: ["2 cups flour", "1 tsp salt", "3 eggs"])
        let result = await appender.addToShoppingList(recipe)

        #expect(result == .added(count: 3))
        #expect(hydrate.callCount == 0)  // populated → no fetch
        #expect(store.load()?.items.count == 3)
    }

    /// An EMPTY-ingredients recipe is routed through the hydrate closure, and
    /// the hydrated ingredients are what get appended.
    @Test func emptyRecipeHydratesThenAppends() async {
        let store = Self.freshStore()
        let hydrate = SpyHydrate()
        hydrate.result = Self.recipe(id: 7, ingredients: ["1 lb chicken", "2 limes"])
        let appender = LiveShoppingListAppender(hydrate: hydrate.call, store: store)

        let empty = Self.recipe(id: 7, ingredients: [])
        let result = await appender.addToShoppingList(empty)

        #expect(result == .added(count: 2))
        #expect(hydrate.callCount == 1)  // empty → fetched once
        #expect(store.load()?.items.count == 2)
    }

    /// An empty recipe the hydrate path can't fill (offline / unfetchable) is
    /// reported as `.couldntLoad` and nothing is persisted.
    @Test func unhydratableRecipeReportsCouldntLoad() async {
        let store = Self.freshStore()
        let hydrate = SpyHydrate()  // no result set → returns the recipe unchanged
        let appender = LiveShoppingListAppender(hydrate: hydrate.call, store: store)

        let empty = Self.recipe(id: 9, ingredients: [])
        let result = await appender.addToShoppingList(empty)

        #expect(result == .couldntLoad)
        #expect(hydrate.callCount == 1)
        #expect(store.load() == nil)  // nothing written
    }

    /// No App-Group store (nil) → `.couldntLoad`, never a crash or a false
    /// "added".
    @Test func nilStoreReportsCouldntLoad() async {
        let appender = LiveShoppingListAppender(store: nil)
        let recipe = Self.recipe(id: 2, ingredients: ["1 onion"])
        let result = await appender.addToShoppingList(recipe)
        #expect(result == .couldntLoad)
    }

    /// Appending is additive across calls for DISTINCT recipes (per-recipe rows
    /// stack — CL-77), but DUT-589: re-appending the SAME recipe de-dups on the
    /// `(recipeTitle, ingredientText)` pair so it no longer double-stacks (which
    /// is what grew the App-Group blob without bound).
    @Test func appendsAreAdditiveAcrossCallsButDeDupSameRecipe() async {
        let store = Self.freshStore()
        let appender = LiveShoppingListAppender(store: store)
        let recipe = Self.recipe(id: 3, ingredients: ["1 onion", "2 carrots"])

        _ = await appender.addToShoppingList(recipe)
        _ = await appender.addToShoppingList(recipe)  // same recipe → de-duped
        #expect(store.load()?.items.count == 2)  // not 4 — no re-stack (DUT-589)

        // A DIFFERENT recipe still stacks additively.
        _ = await appender.addToShoppingList(Self.recipe(id: 4, ingredients: ["3 eggs"]))
        #expect(store.load()?.items.count == 3)
    }

    // MARK: - Subset append (DUT-535 — the selection sheet path)

    /// ``addToShoppingList(rows:)`` appends EXACTLY the given rows and reports
    /// their count — no re-classify, no hydrate.
    @Test func subsetAppendAppendsGivenRowsAndReportsCount() async {
        let store = Self.freshStore()
        let appender = LiveShoppingListAppender(store: store)

        let rows = ShoppingListViewModel.rows(
            from: [Self.recipe(id: 1, ingredients: ["milk", "eggs", "flour"])]
        )
        // Simulate a deselection: only two of the three candidate rows.
        let chosen = Array(rows.prefix(2))
        let result = await appender.addToShoppingList(rows: chosen)

        #expect(result == .added(count: 2))
        let saved = store.load()
        #expect(saved?.items.count == 2)
        #expect(saved?.items.map(\.ingredientText) == ["milk", "eggs"])
    }

    /// An empty selection reports `.couldntLoad` and writes nothing (the sheet's
    /// disabled-at-zero confirm normally prevents this, but the seam is safe).
    @Test func subsetAppendWithNoRowsReportsCouldntLoad() async {
        let store = Self.freshStore()
        let appender = LiveShoppingListAppender(store: store)
        let result = await appender.addToShoppingList(rows: [])
        #expect(result == .couldntLoad)
        #expect(store.load() == nil)
    }

    /// A nil store (no App Group) reports `.couldntLoad`, never a crash.
    @Test func subsetAppendWithNilStoreReportsCouldntLoad() async {
        let appender = LiveShoppingListAppender(store: nil)
        let rows = ShoppingListViewModel.rows(
            from: [Self.recipe(id: 1, ingredients: ["salt"])]
        )
        let result = await appender.addToShoppingList(rows: rows)
        #expect(result == .couldntLoad)
    }

    /// The subset append PRESERVES the existing checked / already-have sets, the
    /// same way the whole-recipe append does — a half-shopped list isn't reset.
    @Test func subsetAppendPreservesCheckedAndAlreadyHave() async {
        let store = Self.freshStore()

        let seed = ShoppingListViewModel.rows(
            from: [Self.recipe(id: 1, ingredients: ["milk", "eggs"])]
        )
        let checked: Set<UUID> = [seed[0].id]
        let alreadyHave: Set<UUID> = [seed[1].id]
        store.save(items: seed, checked: checked, alreadyHave: alreadyHave)

        let appender = LiveShoppingListAppender(store: store)
        let more = ShoppingListViewModel.rows(
            from: [Self.recipe(id: 2, ingredients: ["flour"])]
        )
        _ = await appender.addToShoppingList(rows: more)

        let snapshot = store.load()
        #expect(snapshot?.items.count == 3)
        #expect(Set(snapshot?.checkedIDs ?? []) == checked)
        #expect(Set(snapshot?.alreadyHaveIDs ?? []) == alreadyHave)
    }

    // MARK: - Store append: preserves checked / already-have, survives reload

    /// ``ShoppingListStore/append(rows:)`` appends onto an existing list and
    /// PRESERVES the checked + already-have sets, and the merged state survives
    /// a fresh `load()`.
    @Test func storeAppendPreservesCheckedAndAlreadyHave() {
        let store = Self.freshStore()

        // Seed a half-shopped list: one row checked, one marked already-have.
        let seed = ShoppingListViewModel.rows(
            from: [Self.recipe(id: 1, ingredients: ["milk", "eggs"])]
        )
        let checked: Set<UUID> = [seed[0].id]
        let alreadyHave: Set<UUID> = [seed[1].id]
        store.save(items: seed, checked: checked, alreadyHave: alreadyHave)

        // External append of a second recipe's rows.
        let more = ShoppingListViewModel.rows(
            from: [Self.recipe(id: 2, ingredients: ["flour"])]
        )
        store.append(rows: more)

        let snapshot = store.load()
        #expect(snapshot?.items.count == 3)  // 2 seeded + 1 appended
        #expect(Set(snapshot?.checkedIDs ?? []) == checked)
        #expect(Set(snapshot?.alreadyHaveIDs ?? []) == alreadyHave)
    }

    /// Appending against an empty (never-written) store just writes the rows.
    @Test func storeAppendOntoEmptyStoreWritesRows() {
        let store = Self.freshStore()
        #expect(store.load() == nil)

        let rows = ShoppingListViewModel.rows(
            from: [Self.recipe(id: 1, ingredients: ["a", "b"])]
        )
        store.append(rows: rows)

        #expect(store.load()?.items.count == 2)
    }

    // MARK: - Reload-on-appear lost-update guard

    /// The core DUT-534 guard: a Saved-tab `ShoppingListViewModel` that loaded
    /// on init does NOT see an external append until it reloads — and after
    /// `reloadFromStore()` a subsequent in-list mutation persists the MERGED
    /// set, not the stale one.
    @Test func externalAppendSurfacesAfterReloadAndSurvivesMutation() async {
        let store = Self.freshStore()

        // The list VM loads from the store (starts empty).
        let listVM = ShoppingListViewModel(store: store)
        #expect(listVM.isEmpty)

        // Meanwhile, an external append lands (a card / detail "Add to list").
        let appender = LiveShoppingListAppender(store: store)
        _ = await appender.addToShoppingList(
            Self.recipe(id: 42, ingredients: ["1 cup rice", "2 cups broth"])
        )

        // The VM still shows empty until it reloads on appear.
        #expect(listVM.isEmpty)

        listVM.reloadFromStore()
        #expect(listVM.remainingCount == 2)

        // A subsequent in-list mutation persists the MERGED set — the external
        // rows are NOT clobbered.
        let firstRow = listVM.visibleItems[0]
        listVM.toggleChecked(firstRow)

        let persisted = store.load()
        #expect(persisted?.items.count == 2)  // external rows survived the persist
        #expect(Set(persisted?.checkedIDs ?? []) == [firstRow.id])
    }

    /// `reloadFromStore()` is a no-op against a nil store (in-memory VM) and
    /// against a never-written store (doesn't blank a freshly built list).
    @Test func reloadIsNoOpWithoutPersistedSnapshot() {
        // nil store — in-memory list with rows stays intact.
        let inMemory = ShoppingListViewModel(
            items: ShoppingListViewModel.rows(from: [Self.recipe(id: 1, ingredients: ["x"])]),
            store: nil
        )
        inMemory.reloadFromStore()
        #expect(inMemory.remainingCount == 1)

        // real but empty store — a built-in-memory list isn't wiped by appear.
        let store = Self.freshStore()
        let built = ShoppingListViewModel(
            items: ShoppingListViewModel.rows(from: [Self.recipe(id: 2, ingredients: ["y", "z"])]),
            store: store
        )
        built.reloadFromStore()
        #expect(built.remainingCount == 2)
    }

    // MARK: - Fixtures

    /// A `ShoppingListStore` backed by a throwaway, per-test `UserDefaults`
    /// suite so tests never touch the App Group or `.standard`.
    static func freshStore() -> ShoppingListStore {
        let suite = "dut534.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        return ShoppingListStore(defaults: defaults)
    }

    static func recipe(id: Int, ingredients: [String]) -> Recipe {
        Recipe(
            id: id,
            slug: "s\(id)",
            title: "Title \(id)",
            excerpt: "Excerpt",
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/\(id)/") ?? URL(filePath: "/"),
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            ingredients: ingredients.map { .init(text: $0) }
        )
    }
}

/// A spy hydrate closure: records how many times it was asked to hydrate and
/// returns `result` (or the input unchanged when `result` is nil, modeling the
/// offline / unfetchable path). Backed by a `Mutex`-free actor-isolated box so
/// the `@Sendable` closure the appender takes is data-race safe.
final class SpyHydrate: @unchecked Sendable {
    private let lock = NSLock()
    private var _result: Recipe?
    private var _callCount = 0

    var result: Recipe? {
        get { lock.withLock { _result } }
        set { lock.withLock { _result = newValue } }
    }

    var callCount: Int { lock.withLock { _callCount } }

    var call: @Sendable (Recipe) async -> Recipe {
        { [self] recipe in
            lock.withLock {
                _callCount += 1
                return _result ?? recipe
            }
        }
    }
}

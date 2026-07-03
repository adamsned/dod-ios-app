import DODDomain
import DODSupport
import Foundation
import Testing

@testable import DODFeatureSaved

/// L1 coverage for the Shopping List persistence added by DUT-488 — the
/// ``ShoppingListStore`` round-trip and the ``ShoppingListViewModel`` load /
/// save / clearAll wiring. Verifies the list survives a force-quit (modeled as
/// re-constructing a view-model over the SAME store) and that the explicit-data
/// inits are never clobbered by a saved snapshot.
///
/// Every test uses a throwaway per-test `UserDefaults(suiteName:)` so nothing
/// touches the real App Group suite or `.standard` (mirrors the widget snapshot
/// tests' parallel-safe posture).
@MainActor
@Suite("ShoppingList persistence (DUT-488)") struct ShoppingListPersistenceTests {

    // MARK: - Store round-trip

    @Test func saveThenLoadRestoresItemsCheckedAndAlreadyHave() throws {
        let store = try Self.freshStore()
        let items = [
            Self.item("1 onion", "R", .produce),
            Self.item("1 lb chicken", "R", .meat),
            Self.item("1 tsp salt", "R", .spices),
        ]
        let checked: Set<UUID> = [items[0].id]
        let alreadyHave: Set<UUID> = [items[2].id]

        store.save(items: items, checked: checked, alreadyHave: alreadyHave)

        let snapshot = try #require(store.load())
        #expect(snapshot.items == items)
        #expect(Set(snapshot.checkedIDs) == checked)
        #expect(Set(snapshot.alreadyHaveIDs) == alreadyHave)
    }

    @Test func loadReturnsNilWhenNothingSaved() throws {
        let store = try Self.freshStore()
        #expect(store.load() == nil)
    }

    @Test func loadReturnsNilOnCorruptPayload() throws {
        // A garbage blob under the key must be treated as "no saved list"
        // (never throws / crashes on launch).
        let defaults = try Self.freshDefaults()
        defaults.set(Data("not json".utf8), forKey: ShoppingListStore.key)
        let store = ShoppingListStore(defaults: defaults)
        #expect(store.load() == nil)
    }

    // MARK: - View-model load

    @Test func viewModelWithEmptyStoreStartsEmpty() throws {
        let store = try Self.freshStore()
        let viewModel = ShoppingListViewModel(store: store)
        #expect(viewModel.isEmpty)
        #expect(viewModel.items.isEmpty)
    }

    @Test func viewModelLoadsPersistedStateOnConstruction() throws {
        // Force-quit + reopen: save via one VM, then a fresh VM over the SAME
        // store restores items + checked + already-have.
        let store = try Self.freshStore()
        let first = ShoppingListViewModel(store: store)
        first.add(recipes: [
            Self.recipe(id: 1, title: "A", ingredients: ["1 onion", "1 lb chicken", "1 tsp salt"])
        ])
        let onion = try #require(first.items.first { $0.ingredientText == "1 onion" })
        let salt = try #require(first.items.first { $0.ingredientText == "1 tsp salt" })
        first.toggleChecked(onion)
        first.markAlreadyHave(salt)

        // Reopen.
        let reopened = ShoppingListViewModel(store: store)
        #expect(reopened.items.map(\.ingredientText) == ["1 onion", "1 lb chicken", "1 tsp salt"])
        #expect(reopened.checkedIDs == [onion.id])
        #expect(reopened.alreadyHaveIDs == [salt.id])
        // Derived render model reflects the restored state.
        #expect(reopened.isChecked(onion))
        #expect(reopened.remainingCount == 2)  // salt dropped out (already-have)
    }

    // MARK: - Mutations persist

    @Test func addPersists() throws {
        let store = try Self.freshStore()
        let viewModel = ShoppingListViewModel(store: store)
        viewModel.add(recipes: [Self.recipe(id: 1, title: "A", ingredients: ["1 onion"])])

        let snapshot = try #require(store.load())
        #expect(snapshot.items.map(\.ingredientText) == ["1 onion"])
    }

    @Test func toggleCheckedPersists() throws {
        let store = try Self.freshStore()
        let item = Self.item("1 onion", "R", .produce)
        let viewModel = ShoppingListViewModel(items: [item], store: store)
        viewModel.toggleChecked(item)

        let snapshot = try #require(store.load())
        #expect(Set(snapshot.checkedIDs) == [item.id])
    }

    @Test func markAlreadyHavePersists() throws {
        let store = try Self.freshStore()
        let item = Self.item("1 onion", "R", .produce)
        let viewModel = ShoppingListViewModel(items: [item], store: store)
        viewModel.markAlreadyHave(item)

        let snapshot = try #require(store.load())
        #expect(Set(snapshot.alreadyHaveIDs) == [item.id])
    }

    // MARK: - clearAll

    @Test func clearAllEmptiesAndPersists() throws {
        let store = try Self.freshStore()
        let viewModel = ShoppingListViewModel(store: store)
        viewModel.add(recipes: [
            Self.recipe(id: 1, title: "A", ingredients: ["1 onion", "1 tsp salt"])
        ])
        let onion = try #require(viewModel.items.first)
        viewModel.toggleChecked(onion)
        #expect(!viewModel.isEmpty)

        viewModel.clearAll()
        #expect(viewModel.isEmpty)
        #expect(viewModel.items.isEmpty)
        #expect(viewModel.checkedIDs.isEmpty)
        #expect(viewModel.alreadyHaveIDs.isEmpty)

        // Persisted empty — a reopen stays empty.
        let snapshot = try #require(store.load())
        #expect(snapshot.items.isEmpty)
        #expect(snapshot.checkedIDs.isEmpty)
        #expect(snapshot.alreadyHaveIDs.isEmpty)
        let reopened = ShoppingListViewModel(store: store)
        #expect(reopened.isEmpty)
    }

    // MARK: - Explicit inits are not clobbered

    @Test func explicitInitItemsTakesGivenDataNotSavedList() throws {
        // Pre-seed the store with an unrelated saved list.
        let store = try Self.freshStore()
        store.save(items: [Self.item("stale row", "Old", .other)], checked: [], alreadyHave: [])

        // init(items:) must use the GIVEN items, never the saved snapshot.
        let explicit = [Self.item("1 onion", "R", .produce)]
        let viewModel = ShoppingListViewModel(items: explicit, store: store)
        #expect(viewModel.items == explicit)
        #expect(viewModel.items.map(\.ingredientText) == ["1 onion"])
    }

    @Test func explicitInitRecipesTakesGivenDataNotSavedList() throws {
        let store = try Self.freshStore()
        store.save(items: [Self.item("stale row", "Old", .other)], checked: [], alreadyHave: [])

        let viewModel = ShoppingListViewModel(
            recipes: [Self.recipe(id: 1, title: "A", ingredients: ["1 onion", "1 tsp salt"])],
            store: store
        )
        #expect(viewModel.items.count == 2)
        #expect(viewModel.items.map(\.recipeTitle) == ["A", "A"])
        // Explicit inits don't persist on construction (DUT-488) — the stale
        // saved payload is untouched until a mutation writes over it.
        let untouched = try #require(store.load())
        #expect(untouched.items.map(\.ingredientText) == ["stale row"])
        // A mutation then persists the explicit list (overwriting the stale one).
        let onion = try #require(viewModel.items.first)
        viewModel.toggleChecked(onion)
        let saved = try #require(store.load())
        #expect(saved.items.map(\.recipeTitle) == ["A", "A"])
    }

    @Test func mockUsesNoStoreSoNeverTouchesAppGroup() {
        // `.mock` passes `store: nil` — it's a pure in-memory fixture.
        let viewModel = ShoppingListViewModel.mock
        #expect(!viewModel.isEmpty)
        #expect(viewModel.items.count == 18)
    }

    // MARK: - Fixtures

    private static func freshStore() throws -> ShoppingListStore {
        ShoppingListStore(defaults: try freshDefaults())
    }

    private static func freshDefaults() throws -> UserDefaults {
        // Per-test suite name keeps tests parallel-safe — never touches the App
        // Group suite or `.standard`.
        let name = "dod.shoppingList.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private static func item(
        _ text: String,
        _ recipe: String,
        _ aisle: IngredientAisleClassifier.Aisle
    ) -> ShoppingListViewModel.Item {
        ShoppingListViewModel.Item(ingredientText: text, recipeTitle: recipe, aisle: aisle)
    }

    private static func recipe(id: Int, title: String, ingredients: [String]) -> Recipe {
        Recipe(
            id: id,
            slug: "r\(id)",
            title: title,
            excerpt: "",
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/\(id)/") ?? URL(filePath: "/"),
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            ingredients: ingredients.map { RecipeIngredient(text: $0) },
            instructions: [.init(step: 1, text: "Cook.")]
        )
    }
}

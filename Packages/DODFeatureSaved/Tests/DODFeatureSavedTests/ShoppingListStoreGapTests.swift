import DODSupport
import Foundation
import Testing

@testable import DODFeatureSaved

/// L1 coverage for genuine test gaps in ``ShoppingListStore`` — de-duplication,
/// return-value correctness, idempotence, and edge cases not covered by
/// ShoppingListPersistenceTests and ShoppingListAppenderTests.
///
/// Every test uses a throwaway per-test `UserDefaults(suiteName:)` so nothing
/// touches the real App Group suite or `.standard` (mirrors the existing store
/// test posture).
@MainActor
@Suite("ShoppingListStore gap coverage")
struct ShoppingListStoreGapTests {

    // MARK: - append() return value correctness

    @Test
    func appendReturnValueWhenAllRowsAreDuplicates() {
        let store = Self.freshStore()

        // Seed the store with two rows.
        let seed = [
            Self.item("2 cups flour", "Bread", .pantry),
            Self.item("1 tsp salt", "Bread", .spices),
        ]
        store.save(items: seed, checked: [], alreadyHave: [])

        // Append the SAME rows again — all duplicates → return 0.
        let count = store.append(rows: seed)
        #expect(count == 0)

        // Verify the store hasn't grown — still exactly 2 items.
        let snapshot = store.load()
        #expect(snapshot?.items.count == 2)
    }

    @Test
    func appendReturnValueWhenAllRowsAreNew() {
        let store = Self.freshStore()

        let rows = [
            Self.item("1 onion", "Stew", .produce),
            Self.item("2 lbs beef", "Stew", .meat),
            Self.item("1 cup water", "Stew", .pantry),
        ]
        let count = store.append(rows: rows)

        // All rows are new → return count matches input count.
        #expect(count == 3)
        let snapshot = store.load()
        #expect(snapshot?.items.count == 3)
    }

    @Test
    func appendReturnValueWhenPartiallyDuplicated() {
        let store = Self.freshStore()

        // Seed with two rows.
        let seed = [
            Self.item("2 cups flour", "Bread", .pantry),
            Self.item("1 tsp salt", "Bread", .spices),
        ]
        store.save(items: seed, checked: [], alreadyHave: [])

        // Append four rows: the two seeds + two new ones.
        let mixed = [
            Self.item("2 cups flour", "Bread", .pantry),  // duplicate
            Self.item("1 tsp salt", "Bread", .spices),  // duplicate
            Self.item("1 egg", "Bread", .pantry),  // new
            Self.item("1 cup milk", "Bread", .pantry),  // new
        ]
        let count = store.append(rows: mixed)

        // Only the two new rows actually append → return 2.
        #expect(count == 2)
        let snapshot = store.load()
        #expect(snapshot?.items.count == 4)  // 2 original + 2 appended
    }

    @Test
    func appendReturnValueOnEmptyStore() {
        let store = Self.freshStore()
        #expect(store.load() == nil)

        let rows = [
            Self.item("1 onion", "Soup", .produce),
            Self.item("2 cups broth", "Soup", .pantry),
        ]
        let count = store.append(rows: rows)

        // Empty store → all rows are new → return count.
        #expect(count == 2)
    }

    // MARK: - append() idempotence and state preservation

    @Test
    func appendIsIdempotent() {
        let store = Self.freshStore()

        let rows = [
            Self.item("1 garlic clove", "Pasta", .produce),
            Self.item("1 lb pasta", "Pasta", .pantry),
        ]

        // First append.
        let count1 = store.append(rows: rows)
        #expect(count1 == 2)

        // Second append with identical rows.
        let count2 = store.append(rows: rows)
        #expect(count2 == 0)

        // Store size stable.
        let snapshot = store.load()
        #expect(snapshot?.items.count == 2)
    }

    @Test
    func appendPreservesCheckedAndAlreadyHaveAcrossMultipleAppends() {
        let store = Self.freshStore()

        // Seed with a half-shopped list.
        let seed = [
            Self.item("milk", "Cake", .dairy),
            Self.item("eggs", "Cake", .dairy),
            Self.item("flour", "Cake", .pantry),
        ]
        let firstChecked: Set<UUID> = [seed[0].id]
        let firstAlreadyHave: Set<UUID> = [seed[1].id]
        store.save(items: seed, checked: firstChecked, alreadyHave: firstAlreadyHave)

        // Append new rows.
        let more = [
            Self.item("sugar", "Cake", .pantry),
            Self.item("vanilla", "Cake", .pantry),
        ]
        store.append(rows: more)

        // After append, checked and alreadyHave MUST survive unchanged.
        let snapshot = store.load()
        #expect(Set(snapshot?.checkedIDs ?? []) == firstChecked)
        #expect(Set(snapshot?.alreadyHaveIDs ?? []) == firstAlreadyHave)
        #expect(snapshot?.items.count == 5)  // 3 original + 2 appended
    }

    // MARK: - empty snapshot persistence

    @Test
    func saveEmptySnapshotAndLoad() {
        let store = Self.freshStore()

        // Save an empty snapshot.
        store.save(items: [], checked: [], alreadyHave: [])

        let snapshot = store.load()
        #expect(snapshot != nil)
        #expect(snapshot?.items.isEmpty == true)
        #expect(snapshot?.checkedIDs.isEmpty == true)
        #expect(snapshot?.alreadyHaveIDs.isEmpty == true)
    }

    @Test
    func appendEmptyRowsIsNoOpAndPreservesExistingState() {
        let store = Self.freshStore()

        // Seed the store.
        let seed = [
            Self.item("1 onion", "Stew", .produce)
        ]
        let checked: Set<UUID> = [seed[0].id]
        store.save(items: seed, checked: checked, alreadyHave: [])

        // Append zero rows.
        let count = store.append(rows: [])

        // No-op: return 0, state unchanged.
        #expect(count == 0)
        let snapshot = store.load()
        #expect(snapshot?.items == seed)
        #expect(Set(snapshot?.checkedIDs ?? []) == checked)
    }

    // MARK: - snapshot encoding/decoding

    @Test
    func snapshotRoundTripPreservesAllFields() {
        let store = Self.freshStore()

        let items = [
            Self.item("2 cups flour", "Bread", .pantry),
            Self.item("1 tsp salt", "Bread", .spices),
            Self.item("1 egg", "Bread", .dairy),
        ]
        let checked: Set<UUID> = [items[0].id, items[2].id]
        let alreadyHave: Set<UUID> = [items[1].id]

        store.save(items: items, checked: checked, alreadyHave: alreadyHave)

        let snapshot = store.load()
        #expect(snapshot?.items == items)
        #expect(Set(snapshot?.checkedIDs ?? []) == checked)
        #expect(Set(snapshot?.alreadyHaveIDs ?? []) == alreadyHave)
    }

    @Test
    func multipleRoundTripsPreserveState() {
        let store = Self.freshStore()

        let items1 = [Self.item("onion", "A", .produce)]
        store.save(items: items1, checked: [items1[0].id], alreadyHave: [])

        // Reload and verify.
        var snapshot = store.load()
        #expect(snapshot?.items == items1)

        // Modify and save again.
        let items2 = items1 + [Self.item("garlic", "A", .produce)]
        store.save(items: items2, checked: [], alreadyHave: [items1[0].id])

        // Reload and verify new state.
        snapshot = store.load()
        #expect(snapshot?.items == items2)
        #expect(snapshot?.checkedIDs.isEmpty == true)
        #expect(Set(snapshot?.alreadyHaveIDs ?? []) == [items1[0].id])
    }

    // MARK: - masked-row behavior in append

    @Test
    func appendWithMaskedRowInStoreExcludesItFromDedup() {
        let store = Self.freshStore()

        // Create a legacy masked row: in items but also in alreadyHaveIDs.
        let masked = Self.item("1 onion", "Pot Roast", .produce)
        let visibleRow = Self.item("2 carrots", "Pot Roast", .produce)
        store.save(
            items: [masked, visibleRow],
            checked: [],
            alreadyHave: [masked.id]  // masked row's id is here
        )

        // Try to re-add the masked row (as if from Recipe Detail).
        let reAdded = [Self.item("1 onion", "Pot Roast", .produce)]
        let count = store.append(rows: reAdded)

        // The masked row is EXCLUDED from de-dup, so the re-add succeeds.
        #expect(count == 1)

        // The store now has both the masked row (still invisible due to alreadyHaveIDs)
        // and the new appended row.
        let snapshot = store.load()
        #expect(snapshot?.items.count == 3)  // masked + visible + new
        #expect(Set(snapshot?.alreadyHaveIDs ?? []) == [masked.id])
    }

    // MARK: - dedup key (recipeTitle, ingredientText)

    @Test
    func dedupKeyIsRecipeTitleAndIngredientTextPair() {
        let store = Self.freshStore()

        // Two rows with the same ingredientText but different recipe titles.
        let row1 = Self.item("salt", "Bread", .spices)
        let row2 = Self.item("salt", "Pasta", .spices)  // same ingredient, different recipe

        store.save(items: [row1], checked: [], alreadyHave: [])

        // Append row2 (different recipe title).
        let count = store.append(rows: [row2])

        // row2 is NOT a duplicate (different recipe title) → appended.
        #expect(count == 1)
        let snapshot = store.load()
        #expect(snapshot?.items.count == 2)
    }

    @Test
    func dedupKeyRequiresBothRecipeTitleAndIngredientTextMatch() {
        let store = Self.freshStore()

        let original = Self.item("2 cups flour", "Bread", .pantry)
        store.save(items: [original], checked: [], alreadyHave: [])

        // Append same ingredient but different recipe title → NOT a duplicate.
        let different = Self.item("2 cups flour", "Cake", .pantry)
        let count = store.append(rows: [different])

        #expect(count == 1)
        let snapshot = store.load()
        #expect(snapshot?.items.count == 2)
    }

    // MARK: - Fixtures

    private static func freshStore() -> ShoppingListStore {
        let suite = "dod.shoppingListStore.gap.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        return ShoppingListStore(defaults: defaults)
    }

    private static func item(
        _ text: String,
        _ recipe: String,
        _ aisle: IngredientAisleClassifier.Aisle
    ) -> ShoppingListViewModel.Item {
        ShoppingListViewModel.Item(ingredientText: text, recipeTitle: recipe, aisle: aisle)
    }
}

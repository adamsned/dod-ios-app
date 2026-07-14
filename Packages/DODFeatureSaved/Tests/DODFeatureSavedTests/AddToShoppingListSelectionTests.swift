import DODDomain
import DODSupport
import Foundation
import Testing

@testable import DODFeatureSaved

/// L1 coverage for DUT-535 — the ingredient-selection sheet's state model
/// (``AddToShoppingListSelection``). Verifies the all-selected default,
/// per-row toggling + the live count, the Select All / None toggle, the aisle
/// grouping, and that "add" hands back only the selected rows.
@MainActor
@Suite("Add to Shopping List selection (DUT-535)")
struct AddToShoppingListSelectionTests {

    /// Every candidate is selected by default — the confirm reproduces add-all
    /// in one tap.
    @Test func candidatesAllSelectedByDefault() {
        let selection = AddToShoppingListSelection(recipe: Self.recipe(["milk", "eggs", "flour"]))
        #expect(selection.candidates.count == 3)
        #expect(selection.selectedCount == 3)
        #expect(selection.isAllSelected)
        #expect(selection.candidates.allSatisfy { selection.isSelected($0) })
    }

    /// Toggling a row changes the selected count and its own selected state,
    /// leaving the others untouched.
    @Test func togglingChangesTheCount() {
        let selection = AddToShoppingListSelection(recipe: Self.recipe(["milk", "eggs", "flour"]))
        let first = selection.candidates[0]

        selection.toggle(first)
        #expect(selection.selectedCount == 2)
        #expect(!selection.isSelected(first))
        #expect(!selection.isAllSelected)

        selection.toggle(first)  // back on
        #expect(selection.selectedCount == 3)
        #expect(selection.isSelected(first))
        #expect(selection.isAllSelected)
    }

    /// The Select All / None toggle clears the whole selection when all are on,
    /// and re-selects everything when not.
    @Test func selectAllToggleFlipsWholeSelection() {
        let selection = AddToShoppingListSelection(recipe: Self.recipe(["milk", "eggs"]))
        #expect(selection.isAllSelected)

        selection.toggleSelectAll()  // → none
        #expect(selection.selectedCount == 0)
        #expect(!selection.isAllSelected)

        selection.toggleSelectAll()  // → all
        #expect(selection.selectedCount == 2)
        #expect(selection.isAllSelected)
    }

    /// A partial selection re-selects everything on the next Select All (not a
    /// no-op just because some were already on).
    @Test func selectAllFromPartialSelectsEverything() {
        let selection = AddToShoppingListSelection(recipe: Self.recipe(["a", "b", "c"]))
        selection.toggle(selection.candidates[0])  // 2 of 3 on, not all-selected
        #expect(!selection.isAllSelected)

        selection.toggleSelectAll()
        #expect(selection.selectedCount == 3)
    }

    /// `selectedRows` returns ONLY the selected candidates, in candidate order.
    @Test func selectedRowsReturnsOnlyChosenInOrder() {
        let selection = AddToShoppingListSelection(recipe: Self.recipe(["milk", "eggs", "flour"]))
        selection.toggle(selection.candidates[1])  // drop "eggs"

        let rows = selection.selectedRows
        #expect(rows.map(\.ingredientText) == ["milk", "flour"])
    }

    /// Candidates group by aisle in `Aisle.allCases` order (matching the
    /// Shopping List sections), omitting empty aisles.
    @Test func groupsByAisleInStoreWalkOrder() {
        // "chicken" → meat, "milk" → dairy, "carrots" → produce, "flour" → pantry.
        let selection = AddToShoppingListSelection(
            recipe: Self.recipe(["1 lb chicken thighs", "1 cup milk", "2 carrots", "2 cups flour"])
        )
        let aisles = selection.groups.map(\.aisle)
        // allCases order is produce → meat → dairy → pantry → spices → other.
        #expect(aisles == [.produce, .meat, .dairy, .pantry])
    }

    /// Empty candidates list yields zero selected, isAllSelected false, no groups.
    @Test func emptyCandidatesList() {
        let selection = AddToShoppingListSelection(candidates: [])

        #expect(selection.selectedCount == 0)
        #expect(!selection.isAllSelected)
        #expect(selection.selectedRows.isEmpty)
        #expect(selection.groups.isEmpty)

        selection.toggleSelectAll()
        #expect(selection.selectedCount == 0)
        #expect(!selection.isAllSelected)
        #expect(selection.selectedRows.isEmpty)
        #expect(selection.groups.isEmpty)
    }

    /// Single item boundary: 1 of 1 selected is all-selected; toggling changes
    /// isAllSelected state.
    @Test func singleItemBoundary() {
        let selection = AddToShoppingListSelection(recipe: Self.recipe(["milk"]))

        #expect(selection.selectedCount == 1)
        #expect(selection.isAllSelected)  // 1 of 1 is all

        selection.toggle(selection.candidates[0])
        #expect(selection.selectedCount == 0)
        #expect(!selection.isAllSelected)  // 0 of 1 is not all
    }

    /// All six aisles (produce, meat, dairy, pantry, spices, other) are returned
    /// in Aisle.allCases order when items span every aisle.
    @Test func allSixAislesPresent() {
        let selection = AddToShoppingListSelection(
            recipe: Self.recipe([
                "2 carrots",  // produce
                "1 lb chicken",  // meat
                "1 cup milk",  // dairy
                "2 cups flour",  // pantry
                "1 tsp salt",  // spices
                "xanthan gum",  // other (unmapped keyword)
            ])
        )

        let aisles = selection.groups.map(\.aisle)
        #expect(aisles == [.produce, .meat, .dairy, .pantry, .spices, .other])
    }

    /// Multiple deselections preserve candidate insertion order in selectedRows
    /// (not re-sorted).
    @Test func multipleDeselectionOrder() {
        let selection = AddToShoppingListSelection(
            recipe: Self.recipe(["milk", "eggs", "flour", "chicken"])
        )

        #expect(selection.selectedCount == 4)

        // Deselect 1st and 3rd (milk and flour)
        selection.toggle(selection.candidates[0])
        selection.toggle(selection.candidates[2])

        #expect(selection.selectedCount == 2)
        let rows = selection.selectedRows
        #expect(rows.map(\.ingredientText) == ["eggs", "chicken"])
    }

    /// Non-adjacent aisle groups (e.g., produce + spices, skipping meat/dairy
    /// /pantry) are returned in correct order, omitting empty aisles.
    @Test func nonAdjacentAisles() {
        let selection = AddToShoppingListSelection(
            recipe: Self.recipe([
                "2 carrots",  // produce
                "1 tsp salt",  // spices
            ])
        )

        let aisles = selection.groups.map(\.aisle)
        #expect(aisles == [.produce, .spices])
    }

    /// selectedRows.count always matches selectedCount after any operation
    /// (toggle, toggleSelectAll).
    @Test func selectedRowsCountAlwaysMatchesSelectedCount() {
        let selection = AddToShoppingListSelection(recipe: Self.recipe(["milk", "eggs", "flour"]))

        #expect(selection.selectedRows.count == selection.selectedCount)
        #expect(selection.selectedCount == 3)

        selection.toggle(selection.candidates[0])
        #expect(selection.selectedRows.count == selection.selectedCount)
        #expect(selection.selectedCount == 2)

        selection.toggleSelectAll()  // partial → all
        #expect(selection.selectedRows.count == selection.selectedCount)
        #expect(selection.selectedCount == 3)

        selection.toggleSelectAll()  // all → none
        #expect(selection.selectedRows.count == selection.selectedCount)
        #expect(selection.selectedCount == 0)
    }

    // MARK: - Fixtures

    static func recipe(_ ingredients: [String]) -> Recipe {
        Recipe(
            id: 1,
            slug: "s1",
            title: "Test Recipe",
            excerpt: "",
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/1/") ?? URL(filePath: "/"),
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            ingredients: ingredients.map { .init(text: $0) }
        )
    }
}

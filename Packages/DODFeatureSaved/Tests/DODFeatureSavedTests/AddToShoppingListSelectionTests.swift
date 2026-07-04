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

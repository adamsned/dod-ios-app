import DODSupport
import Foundation
import Testing

@testable import DODFeatureSaved

/// Tests for ``ShoppingListViewModel.dedupedAppend(existing:adding:)`` and
/// ``ShoppingListViewModel.newRows(existing:adding:)`` (DUT-648).  The de-dup
/// identity is `(recipeTitle, ingredientText, occurrence)` where occurrence is
/// the ordinal of the line among identical lines WITHIN A BATCH.
@Suite("ShoppingListViewModel+Dedup") struct ShoppingListViewModelDedupTests {

    // MARK: - dedupedAppend()

    @Test func emptyExistingAndAddingYieldsEmpty() {
        let existing: [ShoppingListViewModel.Item] = []
        let adding: [ShoppingListViewModel.Item] = []

        let result = ShoppingListViewModel.dedupedAppend(existing: existing, adding: adding)

        #expect(result.isEmpty)
    }

    @Test func addingAllNewRowsIncludesAllAdded() {
        let existing: [ShoppingListViewModel.Item] = []
        let adding = [
            ShoppingListViewModel.Item(
                ingredientText: "2 cups diced apples",
                recipeTitle: "Apple Pie",
                aisle: .produce
            ),
            ShoppingListViewModel.Item(
                ingredientText: "1 cup flour",
                recipeTitle: "Apple Pie",
                aisle: .pantry
            )
        ]

        let result = ShoppingListViewModel.dedupedAppend(existing: existing, adding: adding)

        #expect(result.count == 2)
        #expect(result[0].ingredientText == "2 cups diced apples")
        #expect(result[1].ingredientText == "1 cup flour")
    }

    @Test func addingFullDuplicateOfExistingSkipsAllNew() {
        let id1 = UUID()
        let id2 = UUID()
        let existing = [
            ShoppingListViewModel.Item(
                id: id1,
                ingredientText: "2 cups diced apples",
                recipeTitle: "Apple Pie",
                aisle: .produce
            ),
            ShoppingListViewModel.Item(
                id: id2,
                ingredientText: "1 cup flour",
                recipeTitle: "Apple Pie",
                aisle: .pantry
            )
        ]
        let adding = existing

        let result = ShoppingListViewModel.dedupedAppend(existing: existing, adding: adding)

        // Should return existing + [] = existing (no new rows added)
        #expect(result.count == 2)
        #expect(result[0].ingredientText == "2 cups diced apples")
        #expect(result[1].ingredientText == "1 cup flour")
    }

    @Test func addingPartialDuplicateIncludesOnlyNewRows() {
        let existing = [
            ShoppingListViewModel.Item(
                ingredientText: "2 cups diced apples",
                recipeTitle: "Apple Pie",
                aisle: .produce
            )
        ]
        let adding = [
            ShoppingListViewModel.Item(
                ingredientText: "1 cup sugar",
                recipeTitle: "Sugar Cookie",
                aisle: .pantry
            ),
            ShoppingListViewModel.Item(
                ingredientText: "2 cups diced apples",
                recipeTitle: "Apple Pie",
                aisle: .produce
            ),  // duplicate
        ]

        let result = ShoppingListViewModel.dedupedAppend(existing: existing, adding: adding)

        // Should return existing + [sugar] = 2 items
        #expect(result.count == 2)
        #expect(result[0].ingredientText == "2 cups diced apples")
        #expect(result[0].recipeTitle == "Apple Pie")
        #expect(result[1].ingredientText == "1 cup sugar")
        #expect(result[1].recipeTitle == "Sugar Cookie")
    }

    @Test func legitimatelyRepeatedIngredientInAddingBatchSurvivesBoth() {
        // A recipe like "Soup" that legitimately has "2 cups diced yellow onion" twice
        // should produce two rows with occurrence 0 and 1 (distinct keys), so both survive.
        let existing: [ShoppingListViewModel.Item] = []
        let adding = [
            ShoppingListViewModel.Item(
                ingredientText: "2 cups diced yellow onion",
                recipeTitle: "Soup",
                aisle: .produce
            ),
            ShoppingListViewModel.Item(
                ingredientText: "2 cups diced yellow onion",
                recipeTitle: "Soup",
                aisle: .produce
            )
        ]

        let result = ShoppingListViewModel.dedupedAppend(existing: existing, adding: adding)

        // Both should survive because occurrence 0 and 1 are distinct keys
        #expect(result.count == 2)
        #expect(result[0].ingredientText == "2 cups diced yellow onion")
        #expect(result[0].recipeTitle == "Soup")
        #expect(result[1].ingredientText == "2 cups diced yellow onion")
        #expect(result[1].recipeTitle == "Soup")
    }

    @Test func reAddingSameRecipeWithRepeatedIngredientSkipsBoth() {
        // When the 2-line Soup is already in existing with both occurrences, re-adding
        // the same 2-line batch produces the same occurrence sequence, so both collide
        // and are skipped (no stacking).
        let id1 = UUID()
        let id2 = UUID()
        let existing = [
            ShoppingListViewModel.Item(
                id: id1,
                ingredientText: "2 cups diced yellow onion",
                recipeTitle: "Soup",
                aisle: .produce
            ),
            ShoppingListViewModel.Item(
                id: id2,
                ingredientText: "2 cups diced yellow onion",
                recipeTitle: "Soup",
                aisle: .produce
            )
        ]
        let adding = [
            ShoppingListViewModel.Item(
                ingredientText: "2 cups diced yellow onion",
                recipeTitle: "Soup",
                aisle: .produce
            ),
            ShoppingListViewModel.Item(
                ingredientText: "2 cups diced yellow onion",
                recipeTitle: "Soup",
                aisle: .produce
            )
        ]

        let result = ShoppingListViewModel.dedupedAppend(existing: existing, adding: adding)

        // Should return existing + [] = existing (both occurrences collide and are skipped)
        #expect(result.count == 2)
        #expect(result[0].ingredientText == "2 cups diced yellow onion")
        #expect(result[1].ingredientText == "2 cups diced yellow onion")
    }

    @Test func sameIngredientTextDifferentRecipeDoesNotCollide() {
        // The dedup key includes recipeTitle, so "2 cups diced apples" from "Apple Pie"
        // and "2 cups diced apples" from "Apple Cake" are distinct and both included.
        let existing: [ShoppingListViewModel.Item] = []
        let adding = [
            ShoppingListViewModel.Item(
                ingredientText: "2 cups diced apples",
                recipeTitle: "Apple Pie",
                aisle: .produce
            ),
            ShoppingListViewModel.Item(
                ingredientText: "2 cups diced apples",
                recipeTitle: "Apple Cake",
                aisle: .produce
            )
        ]

        let result = ShoppingListViewModel.dedupedAppend(existing: existing, adding: adding)

        // Both should be included because recipeTitle is part of the dedup key
        #expect(result.count == 2)
        #expect(result[0].ingredientText == "2 cups diced apples")
        #expect(result[0].recipeTitle == "Apple Pie")
        #expect(result[1].ingredientText == "2 cups diced apples")
        #expect(result[1].recipeTitle == "Apple Cake")
    }

    // MARK: - newRows()

    @Test func newRowsReturnsOnlyNonDuplicatesWithoutExistingPrefix() {
        // The newRows function returns the subset of adding that is NOT in existing,
        // without the existing prefix (useful for append patterns where the caller
        // will prepend existing itself).
        let existing = [
            ShoppingListViewModel.Item(
                ingredientText: "Apples",
                recipeTitle: "Pie",
                aisle: .produce
            )
        ]
        let adding = [
            ShoppingListViewModel.Item(
                ingredientText: "Flour",
                recipeTitle: "Pie",
                aisle: .pantry
            ),
            ShoppingListViewModel.Item(
                ingredientText: "Apples",
                recipeTitle: "Pie",
                aisle: .produce
            ),  // duplicate
        ]

        let newRows = ShoppingListViewModel.newRows(existing: existing, adding: adding)

        // Should return only [Flour], not [Flour, Apples]
        #expect(newRows.count == 1)
        #expect(newRows[0].ingredientText == "Flour")
    }

    // MARK: - Complex scenarios

    @Test func complexMultiRecipeScenarioWithPartialOverlaps() {
        // A realistic scenario: adding a mix of new and duplicate rows from multiple recipes.
        let existing = [
            ShoppingListViewModel.Item(
                ingredientText: "2 cups flour",
                recipeTitle: "Cookies",
                aisle: .pantry
            ),
            ShoppingListViewModel.Item(
                ingredientText: "1 cup sugar",
                recipeTitle: "Cookies",
                aisle: .pantry
            ),
            ShoppingListViewModel.Item(
                ingredientText: "2 lbs chicken",
                recipeTitle: "Roast",
                aisle: .meat
            )
        ]
        let adding = [
            ShoppingListViewModel.Item(
                ingredientText: "1 cup butter",
                recipeTitle: "Cookies",
                aisle: .dairy
            ),  // new
            ShoppingListViewModel.Item(
                ingredientText: "2 cups flour",
                recipeTitle: "Cookies",
                aisle: .pantry
            ),  // duplicate
            ShoppingListViewModel.Item(
                ingredientText: "3 lbs beef",
                recipeTitle: "Stew",
                aisle: .meat
            ),  // new recipe
            ShoppingListViewModel.Item(
                ingredientText: "2 lbs chicken",
                recipeTitle: "Roast",
                aisle: .meat
            ),  // duplicate
        ]

        let result = ShoppingListViewModel.dedupedAppend(existing: existing, adding: adding)

        // Should return existing + [butter, beef] = 5 items
        #expect(result.count == 5)
        #expect(result[0].recipeTitle == "Cookies")
        #expect(result[1].recipeTitle == "Cookies")
        #expect(result[2].recipeTitle == "Roast")
        #expect(result[3].ingredientText == "1 cup butter")
        #expect(result[4].ingredientText == "3 lbs beef")
    }
}

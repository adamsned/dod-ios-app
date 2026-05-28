import DODSupport
import Foundation
import Testing

@testable import DODFeatureSaved

/// L1 coverage for ``ShoppingListFormatter`` — the AC-39.7 share-text builder.
/// Pins the aisle-grouped Markdown shape, the store-walk ordering, and the
/// CL-85 exclusion of checked + already-have rows (the deliberate deviation
/// from CL-72's full-list snapshot). Constitution §6 L1.
@MainActor
@Suite("ShoppingListFormatter (T-680c)") struct ShoppingListFormatterTests {

    // MARK: - Format + ordering

    @Test func emptyListRendersHeaderOnly() {
        let viewModel = ShoppingListViewModel(items: [])
        #expect(ShoppingListFormatter.shareText(viewModel) == "Shopping List")
    }

    @Test func groupsByAisleInStoreWalkOrderWithRecipeAttribution() {
        // Deliberately out of store-walk order on input — spices before produce
        // before meat — to prove the formatter re-orders to Aisle.allCases.
        let viewModel = ShoppingListViewModel(items: [
            Self.item("1 tsp cumin", "Tacos", .spices),
            Self.item("2 limes", "Tacos", .produce),
            Self.item("1 lb chicken thighs", "Tacos", .meat),
        ])
        let text = ShoppingListFormatter.shareText(viewModel)
        let expected = """
            Shopping List

            Produce
            - 2 limes (Tacos)

            Meat & Seafood
            - 1 lb chicken thighs (Tacos)

            Spices
            - 1 tsp cumin (Tacos)
            """
        #expect(text == expected)
    }

    @Test func multipleRowsInOneAisleEachGetTheirOwnLine() {
        // CL-77 — per-recipe rows, no merge: two onions from two recipes are
        // two lines, each with its source recipe.
        let viewModel = ShoppingListViewModel(items: [
            Self.item("1 yellow onion", "Pot Roast", .produce),
            Self.item("1 yellow onion", "Tacos", .produce),
        ])
        let text = ShoppingListFormatter.shareText(viewModel)
        #expect(text.contains("- 1 yellow onion (Pot Roast)"))
        #expect(text.contains("- 1 yellow onion (Tacos)"))
        // Exactly one "Produce" header even with two rows.
        #expect(text.components(separatedBy: "Produce").count == 2)
    }

    // MARK: - Exclusions (CL-85 deviation from CL-72)

    @Test func excludesAlreadyHaveRows() {
        let keep = Self.item("2 limes", "Tacos", .produce)
        let have = Self.item("1 tsp salt", "Tacos", .spices)
        let viewModel = ShoppingListViewModel(items: [keep, have])
        viewModel.markAlreadyHave(have)

        let text = ShoppingListFormatter.shareText(viewModel)
        #expect(text.contains("- 2 limes (Tacos)"))
        // The already-have row and its now-empty Spices section are gone.
        #expect(!text.contains("salt"))
        #expect(!text.contains("Spices"))
    }

    @Test func excludesCheckedRowsByDefault() {
        let need = Self.item("2 limes", "Tacos", .produce)
        let got = Self.item("1 lb chicken thighs", "Tacos", .meat)
        let viewModel = ShoppingListViewModel(items: [need, got])
        viewModel.toggleChecked(got)

        let text = ShoppingListFormatter.shareText(viewModel)
        #expect(text.contains("- 2 limes (Tacos)"))
        // Checked row (already grabbed) is excluded from the still-need share.
        #expect(!text.contains("chicken"))
        #expect(!text.contains("Meat & Seafood"))
    }

    @Test func includeCheckedFlagRestoresFullSnapshot() {
        // CL-85 — the single flag that restores CL-72's full-list behavior.
        let need = Self.item("2 limes", "Tacos", .produce)
        let got = Self.item("1 lb chicken thighs", "Tacos", .meat)
        let viewModel = ShoppingListViewModel(items: [need, got])
        viewModel.toggleChecked(got)

        let text = ShoppingListFormatter.shareText(viewModel, includeChecked: true)
        #expect(text.contains("- 2 limes (Tacos)"))
        #expect(text.contains("- 1 lb chicken thighs (Tacos)"))
    }

    @Test func everyRowExcludedRendersHeaderOnly() {
        let only = Self.item("1 tsp salt", "Tacos", .spices)
        let viewModel = ShoppingListViewModel(items: [only])
        viewModel.toggleChecked(only)
        #expect(ShoppingListFormatter.shareText(viewModel) == "Shopping List")
    }

    // MARK: - Fixtures

    static func item(
        _ text: String,
        _ recipe: String,
        _ aisle: IngredientAisleClassifier.Aisle
    ) -> ShoppingListViewModel.Item {
        ShoppingListViewModel.Item(ingredientText: text, recipeTitle: recipe, aisle: aisle)
    }
}

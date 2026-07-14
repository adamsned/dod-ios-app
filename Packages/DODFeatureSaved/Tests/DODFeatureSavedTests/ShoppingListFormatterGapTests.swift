import DODSupport
import Foundation
import Testing

@testable import DODFeatureSaved

/// L1 gap coverage for ``ShoppingListFormatter`` — special characters, single aisle,
/// all-aisle coverage, and format precision.
@MainActor
@Suite("ShoppingListFormatter gaps (T-680c-gaps)") struct ShoppingListFormatterGapTests {

    // MARK: - Special characters (pass-through, no escaping)

    @Test func ingredientTextWithMarkdownCharsPassesLiterally() {
        let viewModel = ShoppingListViewModel(items: [
            Self.item("*bold*", "Salad", .produce),
            Self.item("_italic_", "Sauce", .produce),
            Self.item("[link]", "Recipe", .produce),
        ])
        let text = ShoppingListFormatter.shareText(viewModel)
        #expect(text.contains("- *bold* (Salad)"))
        #expect(text.contains("- _italic_ (Sauce)"))
        #expect(text.contains("- [link] (Recipe)"))
    }

    @Test func recipeeTitleWithParenthesesAndAmpersandPassesLiterally() {
        let viewModel = ShoppingListViewModel(items: [
            Self.item("Broth", "Soup (homemade)", .produce),
            Self.item("Meat", "Stew & Chowder", .meat),
        ])
        let text = ShoppingListFormatter.shareText(viewModel)
        #expect(text.contains("- Broth (Soup (homemade))"))
        #expect(text.contains("- Meat (Stew & Chowder)"))
    }

    @Test func backtickAndBackslashInIngredientTextPassesLiterally() {
        let viewModel = ShoppingListViewModel(items: [
            Self.item("flour `2 cups`", "Bread", .produce),
            Self.item("path\\to\\file", "Recipe", .produce),
        ])
        let text = ShoppingListFormatter.shareText(viewModel)
        #expect(text.contains("- flour `2 cups` (Bread)"))
        #expect(text.contains("- path\\to\\file (Recipe)"))
    }

    // MARK: - Format precision

    @Test func singleAisleWithSingleRowFormatsCorrectly() {
        let viewModel = ShoppingListViewModel(items: [
            Self.item("2 apples", "Apple Pie", .produce)
        ])
        let text = ShoppingListFormatter.shareText(viewModel)
        let expected = """
            Shopping List

            Produce
            - 2 apples (Apple Pie)
            """
        #expect(text == expected)
    }

    @Test func allSixAislesInStoreWalkOrderWhenAllPopulated() {
        // Deliberately input out of order — other, spices, pantry, dairy, meat,
        // produce — to prove the formatter re-orders to Aisle.allCases.
        let viewModel = ShoppingListViewModel(items: [
            Self.item("Rubber bands", "Organizing", .other),
            Self.item("1 tsp oregano", "Pizza", .spices),
            Self.item("2 cups flour", "Bread", .pantry),
            Self.item("1 quart milk", "Cereal", .dairy),
            Self.item("1 lb ground beef", "Tacos", .meat),
            Self.item("3 tomatoes", "Salsa", .produce),
        ])
        let text = ShoppingListFormatter.shareText(viewModel)
        let expected = """
            Shopping List

            Produce
            - 3 tomatoes (Salsa)

            Meat & Seafood
            - 1 lb ground beef (Tacos)

            Dairy
            - 1 quart milk (Cereal)

            Pantry
            - 2 cups flour (Bread)

            Spices
            - 1 tsp oregano (Pizza)

            Other
            - Rubber bands (Organizing)
            """
        #expect(text == expected)
    }

    @Test func singleRowInMiddleAisleOmitsEmptyAisles() {
        // Only dairy populated (aisle 3 of 6); produce, meat, pantry, spices,
        // other should not appear.
        let viewModel = ShoppingListViewModel(items: [
            Self.item("1 gallon yogurt", "Breakfast", .dairy)
        ])
        let text = ShoppingListFormatter.shareText(viewModel)
        let expected = """
            Shopping List

            Dairy
            - 1 gallon yogurt (Breakfast)
            """
        #expect(text == expected)
        #expect(!text.contains("Produce"))
        #expect(!text.contains("Meat & Seafood"))
        #expect(!text.contains("Pantry"))
        #expect(!text.contains("Spices"))
        #expect(!text.contains("Other"))
    }

    @Test func rowsPreserveLeadingTrailingSpacesInIngredientText() {
        // Edge case: ingredient text with leading/trailing spaces should be
        // preserved as-is.
        let viewModel = ShoppingListViewModel(items: [
            Self.item("  apples  ", "Pie", .produce)
        ])
        let text = ShoppingListFormatter.shareText(viewModel)
        #expect(text.contains("- " + "  apples  " + " (Pie)"))
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

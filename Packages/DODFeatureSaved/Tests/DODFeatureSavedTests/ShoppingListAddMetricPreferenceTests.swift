import DODDomain
import DODSupport
import Foundation
import Testing

@testable import DODFeatureSaved

/// L1 coverage for the shared "Use Metric Units" preference at the Saved-tab
/// bulk-picker append path (``ShoppingListViewModel/add(recipes:)``).
///
/// **The bug this covers.** ``ShoppingListAppenderMetricTests`` locked down
/// that a single-recipe "Add to Shopping List" (Recipe Detail / a Feed / Search
/// card, via ``LiveShoppingListAppender``) rewrites appended rows to metric
/// when the preference is on. But ``ShoppingListBuilderSheet``'s "Make
/// Shopping List" bulk picker — the Saved tab's original, oldest entry point
/// onto the list (US-39 / AC-39.3) — appends through
/// ``ShoppingListViewModel/add(recipes:)`` directly, which built rows via
/// `rows(from:)` with NO metric rewrite at all. A metric-mode cook who built
/// their list from Saved recipes got imperial rows, possibly mixed onto a list
/// that already carried metric rows added from Recipe Detail — the same
/// toggle behaving differently depending on which surface was used. These
/// tests pin the fix: ``add(recipes:)`` now applies
/// ``ShoppingListViewModel/applyMetricPreference(_:defaults:)`` too, the same
/// shared rewrite the appender uses.
@MainActor
@Suite("ShoppingListViewModel.add(recipes:) — metric preference")
struct ShoppingListAddMetricPreferenceTests {

    /// With the preference on, the Saved-tab bulk-picker append now converts
    /// each row's ingredient text — matching what a Recipe Detail / Feed /
    /// Search single-recipe append already produced.
    @Test func bulkPickerAddConvertsToMetricWhenPreferenceIsOn() {
        let defaults = Self.freshDefaults()
        defaults.set(true, forKey: IngredientMetricConverter.preferenceKey)
        let viewModel = ShoppingListViewModel(items: [], store: nil, defaults: defaults)

        let recipe = ShoppingListViewModelTests.recipe(
            id: 1,
            title: "Pot Roast",
            ingredients: ["1 cup flour", "1 lb chicken"]
        )
        viewModel.add(recipes: [recipe])

        let texts = viewModel.items.map(\.ingredientText)
        #expect(texts.contains("240 ml flour"))
        #expect(texts.contains("450 g chicken"))
    }

    /// The preference OFF (the default — absent key) leaves rows in their
    /// original imperial text, matching pre-fix behavior exactly.
    @Test func bulkPickerAddLeavesImperialTextWhenPreferenceIsOff() {
        let viewModel = ShoppingListViewModel(items: [], store: nil, defaults: Self.freshDefaults())

        let recipe = ShoppingListViewModelTests.recipe(
            id: 1,
            title: "Pot Roast",
            ingredients: ["1 cup flour"]
        )
        viewModel.add(recipes: [recipe])

        #expect(viewModel.items.map(\.ingredientText) == ["1 cup flour"])
    }

    /// Cross-surface consistency — the actual bug class. The SAME recipe run
    /// through the Saved-tab bulk-picker append (``add(recipes:)``) and the
    /// Recipe Detail / Feed / Search single-recipe append
    /// (``LiveShoppingListAppender``) must agree on ingredient text when the
    /// metric preference is on; before the fix only the appender converted.
    @Test func bulkPickerAgreesWithSingleRecipeAppenderOnMetricText() async {
        let defaults = Self.freshDefaults()
        defaults.set(true, forKey: IngredientMetricConverter.preferenceKey)

        let recipe = ShoppingListAppenderTests.recipe(id: 1, ingredients: ["1 cup flour", "1 lb chicken"])

        let viewModel = ShoppingListViewModel(items: [], store: nil, defaults: defaults)
        viewModel.add(recipes: [recipe])

        let appenderStore = ShoppingListAppenderTests.freshStore()
        let appender = LiveShoppingListAppender(store: appenderStore, defaults: defaults)
        _ = await appender.addToShoppingList(recipe)
        let appenderTexts = appenderStore.load()?.items.map(\.ingredientText) ?? []

        #expect(Set(viewModel.items.map(\.ingredientText)) == Set(appenderTexts))
    }

    // MARK: - Fixtures

    /// A throwaway, per-test `UserDefaults` suite for the metric-preference
    /// parameter — isolated from `.standard` so setting the preference in one
    /// test never leaks into another (mirrors
    /// `ShoppingListAppenderMetricTests.freshDefaults()`).
    static func freshDefaults() -> UserDefaults {
        let suite = "dut534.viewmodel.prefs.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}

import DODDomain
import DODSupport
import Foundation
import Testing

@testable import DODFeatureSaved

/// L1 coverage for the shared "Use Metric Units" preference at the
/// whole-recipe append choke point (``LiveShoppingListAppender/addToShoppingList(_:)``).
///
/// Split into a sibling suite (mirrors `DODDesignSystemTests`'s
/// `SnapshotTests+AppearanceAudit.swift` split) so
/// `ShoppingListAppenderTests.swift` stays under SwiftLint's 400-line
/// `file_length` cap. Reuses that suite's `freshStore(...)` / `recipe(...)`
/// fixtures (both `static func`, so directly callable here) — the split is
/// mechanical, not semantic.
///
/// **The bug this covers.** Recipe Detail's whole-recipe append pre-converts
/// ingredient text to metric client-side
/// (`RecipeDetailViewModel.scaledRecipe`) before it ever reaches
/// `LiveShoppingListAppender`. Feed and Search cards do not — they hand the
/// appender a never-converted `Recipe` built fresh from a lightweight
/// `RecipeListItem` — so before this fix, a cook with "Use Metric Units" on
/// who long-pressed a Feed/Search card and chose "Add to Shopping List" got
/// imperial rows appended onto a list that might already carry metric rows
/// added from Recipe Detail: the SAME toggle behaving differently depending
/// on which surface the append came from.
@MainActor
@Suite("Add to Shopping List appender — metric preference")
struct ShoppingListAppenderMetricTests {

    /// With the preference on, the appender itself now converts each row's
    /// ingredient text — so a Feed/Search card append (which never
    /// pre-converts) matches what Recipe Detail's append already produced.
    @Test func wholeRecipeAppendConvertsToMetricWhenPreferenceIsOn() async {
        let defaults = Self.freshDefaults()
        defaults.set(true, forKey: IngredientMetricConverter.preferenceKey)
        let store = ShoppingListAppenderTests.freshStore()
        let appender = LiveShoppingListAppender(store: store, defaults: defaults)

        let recipe = ShoppingListAppenderTests.recipe(
            id: 1,
            ingredients: ["1 cup flour", "1 lb chicken"]
        )
        let result = await appender.addToShoppingList(recipe)

        #expect(result == .added(count: 2))
        let texts = store.load()?.items.map(\.ingredientText) ?? []
        #expect(texts.contains("240 ml flour"))
        #expect(texts.contains("450 g chicken"))
    }

    /// The preference OFF (the default — absent key) leaves rows in their
    /// original imperial text, matching the pre-fix behavior exactly.
    @Test func wholeRecipeAppendLeavesImperialTextWhenPreferenceIsOff() async {
        let store = ShoppingListAppenderTests.freshStore()
        let appender = LiveShoppingListAppender(store: store, defaults: Self.freshDefaults())

        let recipe = ShoppingListAppenderTests.recipe(id: 1, ingredients: ["1 cup flour"])
        let result = await appender.addToShoppingList(recipe)

        #expect(result == .added(count: 1))
        #expect(store.load()?.items.map(\.ingredientText) == ["1 cup flour"])
    }

    /// The subset-append path (the Recipe Detail selection sheet) deliberately
    /// does NOT consult the metric preference — its candidate rows are already
    /// built from a pre-scaled/pre-converted recipe upstream
    /// (`RecipeDetailView+Toolbar.presentAddToShoppingList`), so re-running the
    /// conversion here would be redundant. Proves the preference-on fix is
    /// scoped to the whole-recipe append and doesn't touch this path.
    @Test func subsetAppendDoesNotApplyMetricPreferenceEvenWhenOn() async {
        let defaults = Self.freshDefaults()
        defaults.set(true, forKey: IngredientMetricConverter.preferenceKey)
        let store = ShoppingListAppenderTests.freshStore()
        let appender = LiveShoppingListAppender(store: store, defaults: defaults)

        let rows = ShoppingListViewModel.rows(
            from: [ShoppingListAppenderTests.recipe(id: 1, ingredients: ["1 cup flour"])]
        )
        let result = await appender.addToShoppingList(rows: rows)

        #expect(result == .added(count: 1))
        #expect(store.load()?.items.map(\.ingredientText) == ["1 cup flour"])
    }

    // MARK: - Fixtures

    /// A throwaway, per-test `UserDefaults` suite for the metric-preference
    /// parameter — isolated from `.standard` AND from
    /// `ShoppingListAppenderTests.freshStore()`'s own (differently-suited)
    /// `UserDefaults`, so setting the preference in one test never leaks into
    /// another.
    static func freshDefaults() -> UserDefaults {
        let suite = "dut534.prefs.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}

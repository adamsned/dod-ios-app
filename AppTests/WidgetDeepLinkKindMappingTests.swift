import DODAnalytics
import DODSupport
import XCTest

@testable import DODApp

/// L1 coverage for `WidgetDeepLink.widgetKind` and `.recipeID` — the two
/// computed properties that map a parsed deep-link `Route` onto the
/// `widgetOpened` analytics payload (spec.md US-9 AC-9.2, US-17 AC-17.4/9).
///
/// `widgetKind` had zero direct coverage: every existing test exercises
/// `WidgetDeepLinkParser.parse(_:)` (the URL → `Route` parse step, covered in
/// DODSupport) or the app-level routing (`RootView.handle(widgetLink:)`), but
/// nothing pinned the Route → WidgetKind mapping itself — including its one
/// genuinely branchy case, `.recipe(_, source:)`, which is the only case
/// whose associated value (not just its own case) decides the outcome.
final class WidgetDeepLinkKindMappingTests: XCTestCase {

    // MARK: - widgetKind

    func test_feed_mapsToFeatured() {
        XCTAssertEqual(WidgetDeepLink.feed.widgetKind, .featured)
    }

    func test_saved_mapsToSaved() {
        XCTAssertEqual(WidgetDeepLink.saved.widgetKind, .saved)
    }

    func test_tip_mapsToCookingTip() {
        XCTAssertEqual(WidgetDeepLink.tip(index: 3).widgetKind, .cookingTip)
    }

    func test_shoppingList_mapsToSaved() {
        // DUT-480 / DUT-536 — the Control Center control's Shopping List
        // shortcut still attributes to the Saved widget surface.
        XCTAssertEqual(WidgetDeepLink.shoppingList.widgetKind, .saved)
    }

    func test_cookingTool_mapsToSaved() {
        // DUT-674 — the `dod://<tool>` URL fallback maps to the same surface
        // as `.shoppingList`, regardless of which tool it names.
        XCTAssertEqual(WidgetDeepLink.cookingTool(.heatCoach).widgetKind, .saved)
        XCTAssertEqual(WidgetDeepLink.cookingTool(.cookMode).widgetKind, .saved)
    }

    /// The one genuinely branchy case: `.recipe`'s outcome depends on its
    /// `source` associated value, not just the case itself.
    func test_recipe_withFeaturedSource_mapsToFeatured() {
        XCTAssertEqual(WidgetDeepLink.recipe(id: 7, source: .featured).widgetKind, .featured)
    }

    func test_recipe_withSavedSource_mapsToSaved() {
        XCTAssertEqual(WidgetDeepLink.recipe(id: 7, source: .saved).widgetKind, .saved)
    }

    /// `source` defaults to `.featured` for back-compat with pre-T-323 URLs
    /// that omitted the query — pin the default explicitly.
    func test_recipe_withDefaultedSource_mapsToFeatured() {
        XCTAssertEqual(WidgetDeepLink.recipe(id: 7).widgetKind, .featured)
    }

    // MARK: - recipeID

    func test_recipe_recipeIDReturnsTheCarriedID() {
        XCTAssertEqual(WidgetDeepLink.recipe(id: 42, source: .saved).recipeID, 42)
    }

    func test_feed_recipeIDIsNil() {
        XCTAssertNil(WidgetDeepLink.feed.recipeID)
    }

    func test_saved_recipeIDIsNil() {
        XCTAssertNil(WidgetDeepLink.saved.recipeID)
    }

    func test_tip_recipeIDIsNil() {
        XCTAssertNil(WidgetDeepLink.tip(index: 1).recipeID)
    }

    func test_shoppingList_recipeIDIsNil() {
        XCTAssertNil(WidgetDeepLink.shoppingList.recipeID)
    }

    func test_cookingTool_recipeIDIsNil() {
        XCTAssertNil(WidgetDeepLink.cookingTool(.firstCookout).recipeID)
    }
}

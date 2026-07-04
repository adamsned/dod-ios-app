import XCTest

@testable import DODApp

/// L1 unit coverage for `AppTab`. Pins the spec-mandated case order +
/// per-case icon / telemetry mapping so a future refactor can't silently
/// re-shuffle the bottom tab bar or break cross-version funnel analytics.
///
/// Spec trace: US-16 / AC-16.1 (order), AC-16.2 (bookmark icon),
/// AC-16.4 (telemetry names stable). CL-24, CL-25, CL-194 (the Categories
/// tab was removed in T-800 — its browse list moved into Search, CL-193),
/// CL-306 (T-912 / DUT-551 — the Grocery List + Settings tabs retired for the
/// Cooking Tools hub + a header Settings gear).
final class AppTabTests: XCTestCase {

    /// AC-16.1 / CL-25 / CL-194 / CL-306: bottom tab-bar order is **Recipes →
    /// Saved → Cooking Tools → Search** (Categories folded into Search in T-800;
    /// the Grocery List + Settings tabs retired in T-912 / DUT-551 — the Shopping
    /// List folded into the new Cooking Tools hub tab, and Settings moved to a
    /// header gear). `AppTab.allCases` is the single source of truth for that
    /// order (RootView's phoneTabs iterates it directly), so asserting on the
    /// enum is the cheapest possible regression guard.
    func test_allCasesOrderMatchesSpec() {
        XCTAssertEqual(
            AppTab.allCases,
            [.feed, .saved, .cookingTools, .search],
            "Bottom tab bar order is the single source of truth in AppTab.allCases. "
                + "Changing the order here is a user-visible product change — update the "
                + "spec (US-16 / AC-16.1) before touching this test. T-912 / DUT-551 (CL-306) "
                + "replaced the Grocery List + Settings tabs with the Cooking Tools hub."
        )
    }

    /// AC-16.2 / CL-24: the Saved tab uses SF Symbol `bookmark`
    /// (selection-aware — SwiftUI swaps to `bookmark.fill` automatically
    /// when the tab is the active one). Post-T-380 / CL-38, the in-recipe
    /// Save button in `RecipeDetailView` matches this glyph too —
    /// AC-16.3 was amended to drop the original "in-recipe heart
    /// unchanged" carve-out so the affordance for the same action
    /// reads identically across surfaces.
    func test_savedTab_usesBookmarkSymbol() {
        XCTAssertEqual(AppTab.saved.systemImage, "bookmark")
    }

    /// Sanity-check the other tab icons didn't get caught in a sloppy
    /// rename. Pinning them protects against accidental drift in future
    /// passes.
    func test_otherTabs_systemImagesUnchanged() {
        XCTAssertEqual(AppTab.feed.systemImage, "house")
        XCTAssertEqual(AppTab.search.systemImage, "magnifyingglass")
        // T-912 / DUT-551 (CL-306) — the Cooking Tools hub uses `frying.pan`
        // (SwiftUI swaps to `frying.pan.fill` on selection), matching the glyph
        // the retired Cooking Tools menu used.
        XCTAssertEqual(AppTab.cookingTools.systemImage, "frying.pan")
    }

    /// AC-16.4: telemetry names for the surviving tabs are **stable across the
    /// visual change** so existing screen-view event counts remain comparable
    /// before and after US-16 / T-912 lands. The new Cooking Tools token is
    /// added to the constitution §9 allowlist; the retired `grocery` / `settings`
    /// tokens are historical.
    func test_telemetryNames_areStable() {
        XCTAssertEqual(AppTab.feed.telemetryName, "feed")
        XCTAssertEqual(AppTab.saved.telemetryName, "saved")
        XCTAssertEqual(AppTab.search.telemetryName, "search")
        // T-912 / DUT-551 (CL-306) — the Cooking Tools hub's stable token.
        XCTAssertEqual(AppTab.cookingTools.telemetryName, "cooking_tools")
    }

    /// `title` is the **screen-header** string. US-37 / AC-37.1 (T-640)
    /// renamed the feed header to "Recipes & Articles" once the feed began
    /// surfacing article posts alongside recipes. The shorter **bottom-tab
    /// label** is the separate `tabLabel` (pinned by
    /// `test_tabLabels_matchSpec` below) — CL-65 / T-660 split the two so
    /// the tab bar's ~80pt slot doesn't truncate "Recipes & Arti…". Pin
    /// both so a casual rename doesn't slip past code review.
    func test_titles_matchSpec() {
        XCTAssertEqual(AppTab.feed.title, "Recipes & Articles")
        XCTAssertEqual(AppTab.saved.title, "Saved")
        XCTAssertEqual(AppTab.search.title, "Search")
        // T-912 / DUT-551 (CL-306) — the hub header reads the full "Cooking
        // Tools"; the bottom-tab label is the shorter "Tools" (see below).
        XCTAssertEqual(AppTab.cookingTools.title, "Cooking Tools")
    }

    /// AC-16.1 / CL-65 (T-660): the feed tab's bottom-tab label is the short
    /// "Recipes" (the full "Recipes & Articles" lives in `title` for the
    /// screen header). T-912 / DUT-551 (CL-306) adds a second split: the
    /// Cooking Tools hub's label is "Tools" (the full "Cooking Tools" lives in
    /// `title`) so it doesn't truncate the ~80pt tab slot. Pinning `tabLabel`
    /// guards the fixed-width tab slot against a future rename that would
    /// re-introduce the truncation bug.
    func test_tabLabels_matchSpec() {
        XCTAssertEqual(AppTab.feed.tabLabel, "Recipes")
        XCTAssertEqual(AppTab.saved.tabLabel, "Saved")
        XCTAssertEqual(AppTab.search.tabLabel, "Search")
        // T-912 / DUT-551 (CL-306) — short "Tools" for the ~80pt slot.
        XCTAssertEqual(AppTab.cookingTools.tabLabel, "Tools")
    }
}

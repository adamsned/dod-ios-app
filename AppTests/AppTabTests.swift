import XCTest

@testable import DODApp

/// L1 unit coverage for `AppTab`. Pins the spec-mandated case order +
/// per-case icon / telemetry mapping so a future refactor can't silently
/// re-shuffle the bottom tab bar or break cross-version funnel analytics.
///
/// Spec trace: US-16 / AC-16.1 (order), AC-16.2 (bookmark icon),
/// AC-16.4 (telemetry names stable). CL-24, CL-25.
final class AppTabTests: XCTestCase {

    /// AC-16.1 / CL-25: bottom tab-bar order is **Recipes → Categories →
    /// Saved → Search**. `AppTab.allCases` is the single source of truth
    /// for that order (RootView's phoneTabs iterates it directly), so
    /// asserting on the enum is the cheapest possible regression guard.
    func test_allCasesOrderMatchesSpec() {
        XCTAssertEqual(
            AppTab.allCases,
            [.feed, .categories, .saved, .search],
            "Bottom tab bar order is the single source of truth in AppTab.allCases. "
                + "Changing the order here is a user-visible product change — update the "
                + "spec (US-16 / AC-16.1) before touching this test."
        )
    }

    /// AC-16.2 / CL-24: the Saved tab uses SF Symbol `bookmark`
    /// (selection-aware — SwiftUI swaps to `bookmark.fill` automatically
    /// when the tab is the active one). The in-recipe Save heart in
    /// `RecipeDetailView` is intentionally **not** changed here
    /// (AC-16.3) — only the tab icon flips.
    func test_savedTab_usesBookmarkSymbol() {
        XCTAssertEqual(AppTab.saved.systemImage, "bookmark")
    }

    /// Sanity-check the other tab icons didn't get caught in a sloppy
    /// rename. These haven't changed in US-16, but pinning them protects
    /// against accidental drift in future passes.
    func test_otherTabs_systemImagesUnchanged() {
        XCTAssertEqual(AppTab.feed.systemImage, "house")
        XCTAssertEqual(AppTab.categories.systemImage, "square.grid.2x2")
        XCTAssertEqual(AppTab.search.systemImage, "magnifyingglass")
    }

    /// AC-16.4: telemetry names are **stable across the visual change**
    /// so existing screen-view event counts remain comparable before and
    /// after US-16 lands. If we ever do need to rename one of these,
    /// it's a separate, deliberate decision that also touches the
    /// constitution §9 event allowlist.
    func test_telemetryNames_areStable() {
        XCTAssertEqual(AppTab.feed.telemetryName, "feed")
        XCTAssertEqual(AppTab.categories.telemetryName, "categories")
        XCTAssertEqual(AppTab.saved.telemetryName, "saved")
        XCTAssertEqual(AppTab.search.telemetryName, "search")
    }

    /// Title strings are user-visible labels on the tab bar; pin them so
    /// a casual rename doesn't slip past code review.
    func test_titles_matchSpec() {
        XCTAssertEqual(AppTab.feed.title, "Recipes")
        XCTAssertEqual(AppTab.categories.title, "Categories")
        XCTAssertEqual(AppTab.saved.title, "Saved")
        XCTAssertEqual(AppTab.search.title, "Search")
    }
}

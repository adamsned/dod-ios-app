import XCTest

/// DUT-939 / AC-T5 — Discovery and empty-state user journeys.
///
/// Three hermetic L5 journeys that exercise the Surprise Me entry point, the
/// Saved-tab cold-launch empty state, and the Search no-results state.  Every
/// test launches via ``launchForE2E()`` against the in-memory store + network
/// stub (3 canned recipes: corn id 21238, lasagna id 683, peach id 22294) so
/// results are deterministic and no live-blog dependency is needed.
///
/// Anti-flake discipline inherited from the existing suite:
/// - Wait for feed cards before asserting anything that depends on items loaded.
/// - Recipe detail open ⟺ `staticTexts["Ingredients"].waitForExistence(timeout: 15)`.
/// - Dynamic text (no-results title embeds the query) matched via NSPredicate
///   over descendants, not by exact static-text key.
/// - Do NOT assert which recipe Surprise Me picks — only that SOME detail opened.
@MainActor
final class DiscoveryAndEmptyStateJourneysE2ETests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    // MARK: - Journey 1: Surprise Me

    /// DUT-939 — the "Surprise Me" dice button in the Feed header routes to a
    /// recipe detail both times it is tapped (first tap, navigate back, second
    /// tap).  With 3 canned recipes and ``FeedViewModel.lastSurpriseID`` excluding
    /// the previous pick, the second tap is guaranteed to land on a different
    /// recipe, but we intentionally do NOT assert *which* recipe — only that
    /// SOME detail opens.  The button is disabled (not hidden) while the feed has
    /// no items, so we wait for a feed card before asserting its existence.
    func test_surpriseMe_routes_to_recipe_detail_twice() {
        app.launchForE2E()
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "tab bar should appear")

        // Feed must be loaded before the Surprise Me button is enabled.
        let feedCards = app.buttons.matching(identifier: "dod.feed.card")
        XCTAssertTrue(
            feedCards.firstMatch.waitForExistence(timeout: 10),
            "feed cards should be visible before tapping Surprise Me"
        )

        // --- First tap ---
        let surpriseMe = app.buttons["feed-surprise-me"]
        XCTAssertTrue(
            surpriseMe.waitForExistence(timeout: 5),
            "feed-surprise-me button should be present in the Feed header"
        )
        surpriseMe.tap()
        XCTAssertTrue(
            app.staticTexts["Ingredients"].waitForExistence(timeout: 15),
            "first Surprise Me tap should open a recipe detail (Ingredients header hydrates from JSON-LD)"
        )

        // Navigate back to the feed via the navigation bar back button.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(
            feedCards.firstMatch.waitForExistence(timeout: 10),
            "feed cards should be visible again after navigating back from the first Surprise Me detail"
        )

        // --- Second tap ---
        // Re-query the button — element references can become stale after a nav
        // round-trip. The button is re-enabled immediately (items are still in memory).
        let surpriseMeAgain = app.buttons["feed-surprise-me"]
        XCTAssertTrue(
            surpriseMeAgain.waitForExistence(timeout: 5),
            "feed-surprise-me button should still be present for the second tap"
        )
        surpriseMeAgain.tap()
        XCTAssertTrue(
            app.staticTexts["Ingredients"].waitForExistence(timeout: 15),
            "second Surprise Me tap should open a recipe detail (Ingredients header)"
        )
    }

    // MARK: - Journey 2: Empty Saved cold-launch

    /// AC-5.8 — on a fresh ``launchForE2E()`` the in-memory store starts empty,
    /// so the Saved tab must immediately show its empty state.  The identifier
    /// ``saved.emptyState`` is applied in ``SavedView`` as
    /// `.accessibilityIdentifier("saved.emptyState")` on the ``EmptyState``
    /// container, which propagates to descendant static texts so they are
    /// queryable via `app.staticTexts["saved.emptyState"]`.
    func test_saved_tab_shows_empty_state_on_fresh_launch() {
        app.launchForE2E()
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "tab bar should appear")

        tabBar.buttons["Saved"].tap()
        XCTAssertTrue(
            app.staticTexts["saved.emptyState"].firstMatch.waitForExistence(timeout: 8),
            "Saved tab should display its empty state on a fresh hermetic launch (in-memory store is empty)"
        )
    }

    // MARK: - Journey 3: Search no-results

    /// AC-3.4 / US-29 — typing a term that matches none of the 3 canned recipes
    /// transitions ``SearchViewModel`` to `.noResults` and renders an
    /// ``EmptyState`` whose title is "No recipes match '<query>'".  The
    /// ``EmptyState`` for `.noResults` carries no explicit accessibility
    /// identifier in ``SearchView`` (unlike `.offline` / `.error` which have
    /// `dod.search.offlineState` / `dod.search.errorState`), so we match its
    /// title text via an NSPredicate over all descendants — the same anti-flake
    /// idiom used for hydrating text across the suite.
    func test_search_shows_no_results_for_impossible_query() {
        app.launchForE2E()
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "tab bar should appear")
        // Ensure the feed finished its first render before switching tabs (the
        // same guard used in DeterministicJourneysE2ETests).
        XCTAssertTrue(
            app.buttons.matching(identifier: "dod.feed.card").firstMatch.waitForExistence(timeout: 10),
            "feed should finish loading before switching to Search"
        )

        tabBar.buttons["Search"].tap()

        // The search field is the only TextField on the Search tab.
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 8), "search field should appear on the Search tab")
        field.tap()
        // "zzqqxx" matches none of the 3 fixture recipe titles — the stub's
        // postsListJSONObjects(matching:) title-contains filter returns [].
        field.typeText("zzqqxx")

        // After the 150ms debounce the stub returns empty; the view model
        // transitions to .noResults and renders EmptyState with title
        // "No recipes match 'zzqqxx'". Match via predicate so the embedded
        // query string doesn't require an exact literal.
        let noResultsElement = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "No recipes match"))
            .firstMatch
        XCTAssertTrue(
            noResultsElement.waitForExistence(timeout: 10),
            "searching for 'zzqqxx' should show the no-results empty state ('No recipes match ...')"
        )
    }
}

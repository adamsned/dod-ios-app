import DODDomain
import Foundation
import XCTest

@testable import DODApp

/// L1 coverage for `RecipeRouteResolver` — the fetch-on-cache-miss policy
/// behind notification deep-links (T-632 / REG-20 / CL-101).
///
/// The resolver's two I/O edges (cache lookup + remote fetch) are injected
/// as closures so every branch is driven in-process with no SwiftUI host,
/// no network, and no `RecipeStore`. The four cases pin the contract REG-20
/// locks: cache-hit returns a route *without* fetching (widget/Spotlight
/// behavior preserved), cache-miss fetches + routes (the notification fix),
/// an article resolves through the same `.recipe(item:)` route (the detail
/// screen opens `ArticleDetailView`), and an unresolvable id degrades to
/// `nil`.
final class RecipeRouteResolverTests: XCTestCase {

    private enum ResolverTestError: Error { case fetchFailed }

    /// Non-failing URL builder so the fixtures avoid force-unwrapping
    /// (swiftlint `force_unwrapping`). The string literals are static +
    /// well-formed, so the fallback is never taken in practice.
    private func url(_ string: String) -> URL {
        URL(string: string) ?? URL(filePath: "/")
    }

    private func sampleRecipe(id: Int) -> Recipe {
        Recipe(
            id: id,
            slug: "garlic-butter-skillet-corn",
            title: "Garlic Butter Skillet Corn",
            excerpt: "Easy 15-minute side dish.",
            canonicalURL: url("https://www.dutchovendaddy.com/garlic-butter-skillet-corn/"),
            publishedAt: .distantPast
        )
    }

    private func sampleListItem(id: Int, title: String, canonical: String) -> RecipeListItem {
        RecipeListItem(
            id: id,
            title: title,
            excerpt: "",
            publishedAt: .distantPast,
            canonicalURL: url(canonical)
        )
    }

    /// Extract the `RecipeListItem` from a `.recipe` route, failing the
    /// test if the route is any other case.
    private func recipeItem(
        from route: RecipeRoute?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> RecipeListItem? {
        guard case .recipe(let item, _)? = route else {
            XCTFail("expected a .recipe route, got \(String(describing: route))", file: file, line: line)
            return nil
        }
        return item
    }

    /// AC: a cached id returns a route built from the cache — and the fetch
    /// closure is **never** invoked (widget/Spotlight stay network-free,
    /// REG-10). This is the behavior the original cache-only path got right
    /// and the fix must preserve.
    func test_cachedID_returnsRouteWithoutFetching() async {
        var fetchCalled = false
        let route = await RecipeRouteResolver.resolve(
            id: 21238,
            autoStartCookMode: false,
            cachedLookup: { id in self.sampleRecipe(id: id) },
            fetch: { _ in
                fetchCalled = true
                throw ResolverTestError.fetchFailed
            }
        )
        XCTAssertFalse(fetchCalled, "cache hit must not trigger a network fetch")
        XCTAssertEqual(recipeItem(from: route)?.id, 21238)
        XCTAssertEqual(
            recipeItem(from: route)?.canonicalURL?.absoluteString,
            "https://www.dutchovendaddy.com/garlic-butter-skillet-corn/"
        )
    }

    /// AC: an uncached id (the notification case — the post is brand-new and
    /// never cached) fetches the post by id and routes to it, carrying the
    /// fetched `canonicalURL` the detail screen needs to hydrate.
    func test_uncachedID_fetchesAndReturnsRoute() async {
        var fetchedID: Int?
        let route = await RecipeRouteResolver.resolve(
            id: 21238,
            autoStartCookMode: false,
            cachedLookup: { _ in nil },
            fetch: { id in
                fetchedID = id
                return self.sampleListItem(
                    id: id,
                    title: "Garlic Butter Skillet Corn",
                    canonical: "https://www.dutchovendaddy.com/garlic-butter-skillet-corn/"
                )
            }
        )
        XCTAssertEqual(fetchedID, 21238, "cache miss must fetch the post by id")
        XCTAssertEqual(recipeItem(from: route)?.id, 21238)
        XCTAssertEqual(
            recipeItem(from: route)?.canonicalURL?.absoluteString,
            "https://www.dutchovendaddy.com/garlic-butter-skillet-corn/"
        )
    }

    /// AC: an uncached id whose fetch resolves an **article** (PostKind
    /// `.article`, e.g. id 23406) still returns a `.recipe(item:)` route
    /// carrying the article's post. There is no separate article route case
    /// — `RecipeDetailViewModel.fetchAndParse()` classifies the post and
    /// opens `ArticleDetailView`, so routing the article's `RecipeListItem`
    /// (with its `canonicalURL`) here is what makes the article notification
    /// open the article detail (CL-101 decision 2).
    func test_uncachedArticleID_returnsRouteCarryingArticlePost() async {
        let articleURL = "https://www.dutchovendaddy.com/best-dutch-oven-recipes/"
        let route = await RecipeRouteResolver.resolve(
            id: 23406,
            autoStartCookMode: false,
            cachedLookup: { _ in nil },
            fetch: { id in
                self.sampleListItem(
                    id: id,
                    title: "Best Dutch Oven Recipes (30+ Tried and Tested Favorites)",
                    canonical: articleURL
                )
            }
        )
        let item = recipeItem(from: route)
        XCTAssertEqual(item?.id, 23406)
        // The canonicalURL is carried through so the detail screen's fetch
        // path can classify it as an article and render ArticleDetailView.
        XCTAssertEqual(item?.canonicalURL?.absoluteString, articleURL)
    }

    /// AC: an id that is neither cached nor fetchable (post deleted, or the
    /// JSON-LD + article-body extraction both fail per CL-9) degrades
    /// gracefully to `nil` so the caller ignores the deep link rather than
    /// crashing or opening a broken screen.
    func test_uncachedID_fetchFailure_returnsNil() async {
        let route = await RecipeRouteResolver.resolve(
            id: 999,
            autoStartCookMode: false,
            cachedLookup: { _ in nil },
            fetch: { _ in throw ResolverTestError.fetchFailed }
        )
        XCTAssertNil(route, "an unresolvable id must return nil (ignore the deep link)")
    }

    /// DUT-549 AC: a failed resolve (the id is neither cached nor fetchable)
    /// maps to `.failed`, NOT a silent nil the router drops. This is the seam
    /// `RootView.applyDeepLinkResolve` reads to surface a "couldn't open that
    /// recipe" toast instead of dumping the user on a blank Feed.
    func test_deepLinkOutcome_nilRoute_isFailed() {
        XCTAssertEqual(RecipeRouteResolver.outcome(for: nil), .failed)
    }

    /// DUT-549 AC: a resolved route maps to `.route`, so the router pushes it
    /// (and shows no error). Pairs with the failure case above to pin the whole
    /// route-vs-error decision the toast recovery hangs off.
    func test_deepLinkOutcome_resolvedRoute_isRoute() {
        let item = sampleListItem(
            id: 21238,
            title: "Garlic Butter Skillet Corn",
            canonical: "https://www.dutchovendaddy.com/garlic-butter-skillet-corn/"
        )
        let route = RecipeRoute.recipe(item: item, autoStartCookMode: false)
        XCTAssertEqual(RecipeRouteResolver.outcome(for: route), .route(route))
    }

    /// AC: `autoStartCookMode` is forwarded into the resolved route (the
    /// StartCookModeIntent deep-link path, US-10) on the fetch-on-miss
    /// branch too.
    func test_autoStartCookMode_isForwardedOnFetchPath() async {
        let route = await RecipeRouteResolver.resolve(
            id: 21238,
            autoStartCookMode: true,
            cachedLookup: { _ in nil },
            fetch: { id in
                self.sampleListItem(
                    id: id,
                    title: "Garlic Butter Skillet Corn",
                    canonical: "https://www.dutchovendaddy.com/garlic-butter-skillet-corn/"
                )
            }
        )
        guard case .recipe(_, let autoStart)? = route else {
            return XCTFail("expected a .recipe route")
        }
        XCTAssertTrue(autoStart)
    }
}

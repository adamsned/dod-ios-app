import DODDomain
import DODSupport
import Foundation
import Testing

@testable import DODFeatureSearch

/// DUT-574 — user-reported "search is slow and doesn't work right". Root cause:
/// every finalized plain-text search fanned out an extra category fetch (Path B,
/// up to two `?categories=<id>&per_page=100` round-trips) whenever the typed
/// text happened to name a WP category, then unioned ALL of those recent,
/// date-ordered category posts into the results — extra latency + polluted,
/// unstable results. The fix gates Path B on an actually-set category filter,
/// so a plain text search makes exactly ONE primary request.
///
/// These tests pin the reduced per-query cost (perf) and the correctness win
/// (no unrelated category posts polluting a plain-text result set), and guard
/// the didYouMean fetch stays off the critical path.
@MainActor
@Suite("SearchViewModel DUT-574 (search perf + correctness)") struct SearchViewModelDUT574Tests {

    static let liveCategories: [DODDomain.Category] = [
        DODDomain.Category(id: 339, name: "Beef and Red Meat Recipes", slug: "beef-and-red-meat-recipes", count: 28),
        DODDomain.Category(id: 336, name: "Dessert Recipes", slug: "dessert-recipes", count: 53),
    ]

    // MARK: - Perf: exactly one network call for a plain text search

    @Test func plainTextSearchMakesExactlyOnePrimaryRequestNoFanOut() async {
        // "beef" names the "Beef and Red Meat Recipes" category. Pre-DUT-574
        // this fired Path B against category 339 (100 posts) on top of the
        // Path A `?search=beef`. With no filter set, the fix makes it a single
        // primary request and zero category fetches.
        let dependencies = FakeSearchDependencies()
        dependencies.categories = Self.liveCategories
        dependencies.results["beef"] = [Self.makeItem(1, title: "Beef Stew")]
        // Seeded so a regression (Path B firing) would be observable.
        dependencies.categoryFetchResults[339] = Self.bulkPosts(count: 100, idOffset: 5000)

        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )
        await viewModel.loadCategoriesIfNeeded()

        viewModel.query = "beef"
        await viewModel.runImmediateSearch()

        // Exactly one primary REST search, no category fan-out.
        #expect(dependencies.searches == ["beef"], "Exactly one primary ?search= request")
        #expect(dependencies.categoryFetchCalls.isEmpty, "No ?categories= fan-out on a plain text search")
        // And no filter-support table scans on a default (no-filter) search.
        #expect(dependencies.categoryIDsCalls.isEmpty)
        #expect(dependencies.totalSecondsCalls.isEmpty)
        #expect(dependencies.recentlyViewedCallCount == 0)
    }

    // MARK: - Correctness: results aren't polluted by the category

    @Test func plainTextResultsAreOnlyTitleMatchesNotWholeCategory() async {
        // The correctness half of the bug: typing "beef" used to append the
        // entire recent Beef category (100 date-ordered posts, most without
        // "beef" in the title) after the two real title matches — so the user
        // saw a wall of unrelated recipes. Now the result set is exactly the
        // title matches Path A returns.
        let dependencies = FakeSearchDependencies()
        dependencies.categories = Self.liveCategories
        dependencies.results["beef"] = [
            Self.makeItem(1, title: "Beef Stew"),
            Self.makeItem(2, title: "Ground Beef Chili"),
        ]
        dependencies.categoryFetchResults[339] = Self.bulkPosts(count: 100, idOffset: 5000)

        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )
        await viewModel.loadCategoriesIfNeeded()

        viewModel.query = "beef"
        await viewModel.runImmediateSearch()

        #expect(viewModel.state == .results)
        #expect(viewModel.items.map(\.id) == [1, 2], "Only the two title matches — no category pollution")
    }

    // MARK: - didYouMean stays off the critical path (and only when sparse)

    @Test func didYouMeanNotComputedWhenResultsArePlentiful() async {
        // The cached-titles fetch backing "did you mean?" must not run when the
        // result set is already populated (≥ threshold) — it's pure rescue-path
        // cost. Seed a title pool that WOULD produce a suggestion so we can
        // prove it was never consulted.
        let dependencies = FakeSearchDependencies()
        dependencies.categories = Self.liveCategories
        dependencies.results["chicken"] = (1...5).map { Self.makeItem($0, title: "Chicken \($0)") }
        dependencies.cachedTitlesArray = ["Chicken Pot Pie", "Chicken Marsala", "Chicken Tacos"]

        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )
        await viewModel.loadCategoriesIfNeeded()

        viewModel.query = "chicken"
        await viewModel.runImmediateSearch()

        #expect(viewModel.items.count == 5)
        #expect(viewModel.didYouMean == nil, "No rescue banner when results are plentiful")
        #expect(
            dependencies.cachedTitlesCallCount == 0,
            "cachedRecipeTitles must not be fetched when results are plentiful"
        )
    }

    // MARK: - Helpers

    static func bulkPosts(count: Int, idOffset: Int) -> [RecipeListItem] {
        (0..<count).map { idx in
            RecipeListItem(
                id: idOffset + idx,
                title: "Category Filler #\(idx)",
                excerpt: "Excerpt",
                heroImage: nil,
                publishedAt: Date(timeIntervalSince1970: TimeInterval(1_700_000_000 - idx * 86400)),
                totalTimeDisplay: nil
            )
        }
    }

    static func makeItem(_ id: Int, title: String = "Match") -> RecipeListItem {
        RecipeListItem(
            id: id,
            title: title,
            excerpt: "Excerpt",
            heroImage: nil,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            totalTimeDisplay: nil
        )
    }

    static func scratchRecents() -> RecentSearches {
        let suiteName = "dod.searchDUT574Tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return RecentSearches(defaults: defaults, storageKey: "recents")
    }
}

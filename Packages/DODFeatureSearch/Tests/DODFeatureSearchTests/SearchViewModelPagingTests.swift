import DODDomain
import DODSupport
import Foundation
import Testing

@testable import DODFeatureSearch

/// v2 search paging — infinite-scroll paging for the text-search result set.
/// The pipeline used to fetch only `?search=` page 1 and never advance; these
/// prove the near-bottom trigger fetches page 2+, appends deduped, stops on an
/// empty/short page, and resets + cancels in-flight paging on a new query.
@MainActor
@Suite("SearchViewModel infinite-scroll paging") struct SearchViewModelPagingTests {

    /// The first query settles on page 1 alone — no `searchMore` fetch until the
    /// near-bottom trigger fires, and the cursor sits at page 1, not latched.
    @Test func firstQueryYieldsPageOneOnly() async {
        let dependencies = FakeSearchDependencies()
        dependencies.results["chicken"] = [Self.item(1), Self.item(2)]
        let viewModel = Self.makeViewModel(dependencies)

        viewModel.query = "chicken"
        await viewModel.runImmediateSearch()

        #expect(viewModel.items.map(\.id) == [1, 2])
        #expect(dependencies.searchMoreCalls.isEmpty)
        #expect(viewModel.searchResultsPage == 1)
        #expect(viewModel.searchResultsReachedEnd == false)
    }

    /// The near-bottom trigger fetches page 2 and appends its genuinely-new hits,
    /// deduped by id against the page-1 title tier.
    @Test func loadMoreAppendsPageTwoDeduped() async {
        let dependencies = FakeSearchDependencies()
        dependencies.results["chicken"] = [Self.item(1), Self.item(2)]
        // Page 2 repeats id 2 (must dedupe) and adds 3, 4.
        dependencies.pagedResults["chicken"] = [2: [Self.item(2), Self.item(3), Self.item(4)]]
        let viewModel = Self.makeViewModel(dependencies)

        viewModel.query = "chicken"
        await viewModel.runImmediateSearch()
        #expect(viewModel.items.map(\.id) == [1, 2])

        // A near-bottom card (id 2, in the last-3 window) arms the next page.
        await viewModel.loadMoreResultsIfNeeded(currentItem: Self.item(2))

        #expect(viewModel.items.map(\.id) == [1, 2, 3, 4], "page 2 appended, id 2 deduped")
        #expect(dependencies.searchMoreCalls.map(\.page) == [2])
        #expect(viewModel.searchResultsPage == 2)
    }

    /// A near-bottom appearance in the MIDDLE of the list (not the last few rows)
    /// does not trigger a fetch — mirrors the Feed's `suffix(3)` window.
    @Test func midListAppearanceDoesNotPage() async {
        let dependencies = FakeSearchDependencies()
        dependencies.results["chicken"] = (1...10).map { Self.item($0) }
        let viewModel = Self.makeViewModel(dependencies)

        viewModel.query = "chicken"
        await viewModel.runImmediateSearch()

        // id 1 is at the top, well outside the trailing window of a 10-row list.
        await viewModel.loadMoreResultsIfNeeded(currentItem: Self.item(1))
        #expect(dependencies.searchMoreCalls.isEmpty)
    }

    /// An empty page latches the end: it appends nothing and blocks further
    /// trigger fires (no second `searchMore` call).
    @Test func emptyPageStopsFurtherLoads() async {
        let dependencies = FakeSearchDependencies()
        dependencies.results["chicken"] = [Self.item(1), Self.item(2)]
        dependencies.pagedResults["chicken"] = [2: []]
        let viewModel = Self.makeViewModel(dependencies)

        viewModel.query = "chicken"
        await viewModel.runImmediateSearch()

        await viewModel.loadMoreResultsIfNeeded(currentItem: Self.item(2))
        #expect(viewModel.items.map(\.id) == [1, 2], "empty page appended nothing")
        #expect(viewModel.searchResultsReachedEnd == true)

        // A second near-bottom appearance must NOT fetch again.
        await viewModel.loadMoreResultsIfNeeded(currentItem: Self.item(2))
        #expect(dependencies.searchMoreCalls.count == 1, "no further fetch after the end latched")
    }

    /// A short page (fewer than the page size) is appended AND latches the end,
    /// so the query's real last page still surfaces before paging stops.
    @Test func shortPageAppendsThenStops() async {
        let dependencies = FakeSearchDependencies()
        dependencies.results["chicken"] = [Self.item(1), Self.item(2)]
        dependencies.pagedResults["chicken"] = [2: [Self.item(3)]]  // 1 < 100 = last page
        let viewModel = Self.makeViewModel(dependencies)

        viewModel.query = "chicken"
        await viewModel.runImmediateSearch()

        await viewModel.loadMoreResultsIfNeeded(currentItem: Self.item(2))
        #expect(viewModel.items.map(\.id) == [1, 2, 3], "short page appended")
        #expect(viewModel.searchResultsReachedEnd == true)

        await viewModel.loadMoreResultsIfNeeded(currentItem: Self.item(3))
        #expect(dependencies.searchMoreCalls.count == 1, "end latched after the short page")
    }

    /// Server content matches (title-less hits) from a later page extend the
    /// "Recipes Using <term>" ingredient tier, not the title tier.
    @Test func pagedContentMatchesExtendUsingTier() async {
        let dependencies = FakeSearchDependencies()
        dependencies.results["chicken"] = [Self.item(1)]
        // Page 2: id 2 title-matches (title tier); id 3 does NOT (content tier).
        dependencies.pagedResults["chicken"] = [
            2: [Self.item(2), Self.item(3, title: "Slow Braise")]
        ]
        let viewModel = Self.makeViewModel(dependencies)

        viewModel.query = "chicken"
        await viewModel.runImmediateSearch()
        #expect(viewModel.items.map(\.id) == [1])

        await viewModel.loadMoreResultsIfNeeded(currentItem: Self.item(1))
        #expect(viewModel.items.map(\.id) == [1, 2], "title-matching page hit joins the title tier")
        #expect(
            viewModel.ingredientItems.map(\.id) == [3],
            "content-only page hit joins the Recipes Using tier"
        )
    }

    /// A NEW query resets the page cursor + end latch back to page 1.
    @Test func newQueryResetsPaging() async {
        let dependencies = FakeSearchDependencies()
        dependencies.results["chicken"] = [Self.item(1), Self.item(2)]
        dependencies.pagedResults["chicken"] = [2: [Self.item(3)]]
        dependencies.results["beef"] = [Self.item(10, title: "Beef Stew")]
        let viewModel = Self.makeViewModel(dependencies)

        viewModel.query = "chicken"
        await viewModel.runImmediateSearch()
        await viewModel.loadMoreResultsIfNeeded(currentItem: Self.item(2))
        #expect(viewModel.searchResultsPage == 2)

        // Type a new query — paging must restart from page 1.
        viewModel.query = "beef"
        await viewModel.runImmediateSearch()
        #expect(viewModel.items.map(\.id) == [10])
        #expect(viewModel.searchResultsPage == 1)
        #expect(viewModel.searchResultsReachedEnd == false)
    }

    /// A new query issued WHILE a page fetch is in flight bumps the generation;
    /// the stale page's continuation re-checks it and drops its appends rather
    /// than polluting the new query's results.
    @Test func newQueryCancelsInFlightPage() async {
        let dependencies = FakeSearchDependencies()
        dependencies.results["chicken"] = [Self.item(1), Self.item(2)]
        dependencies.pagedResults["chicken"] = [2: [Self.item(3), Self.item(4)]]
        dependencies.results["beef"] = [Self.item(10, title: "Beef Stew")]
        let viewModel = Self.makeViewModel(dependencies)

        viewModel.query = "chicken"
        await viewModel.runImmediateSearch()

        // Park the page-2 fetch in flight.
        let gate = PagingGate()
        dependencies.searchMoreGate = { await gate.wait() }
        let stalePage = Task { @MainActor in
            await viewModel.loadMoreResultsIfNeeded(currentItem: Self.item(2))
        }
        while await !gate.isWaiting { await Task.yield() }

        // A newer "beef" search runs to completion, bumping the generation.
        viewModel.query = "beef"
        await viewModel.runImmediateSearch()
        #expect(viewModel.items.map(\.id) == [10])

        // Release the stale page — it must NOT append 3, 4 onto the beef set.
        await gate.release()
        await stalePage.value

        #expect(viewModel.items.map(\.id) == [10], "stale page dropped by the generation guard")
        #expect(viewModel.searchResultsPage == 1, "beef's page-1 cursor untouched by the stale page")
    }

    // MARK: - Fixtures

    static func item(_ id: Int, title: String? = nil) -> RecipeListItem {
        RecipeListItem(
            id: id,
            title: title ?? "Chicken \(id)",
            excerpt: "Excerpt",
            heroImage: nil,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            totalTimeDisplay: nil
        )
    }

    static func makeViewModel(_ dependencies: FakeSearchDependencies) -> SearchViewModel {
        SearchViewModel(dependencies: dependencies, recentSearches: scratchRecents())
    }

    static func scratchRecents() -> RecentSearches {
        let suiteName = "dod.searchPagingTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return RecentSearches(defaults: defaults, storageKey: "recents")
    }
}

/// One-shot async gate (mirrors `SearchViewModelGenerationTests`' `SearchGate`):
/// a caller parks in `wait()` until the test calls `release()`, and `isWaiting`
/// lets the test spin until the caller has actually parked so the "new query
/// bumps the generation mid-fetch" window is deterministic.
private actor PagingGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var released = false
    private(set) var isWaiting = false

    func wait() async {
        if released { return }
        isWaiting = true
        await withCheckedContinuation { continuation = $0 }
    }

    func release() {
        released = true
        continuation?.resume()
        continuation = nil
    }
}

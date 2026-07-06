import DODDomain
import DODSupport
import Foundation
import Testing

@testable import DODFeatureSearch

/// DUT-622 — a FAILED online REST search (the request threw) must surface a
/// retryable `.error` state, not the misleading `.noResults` "No recipes match
/// '<query>'" dead-end. A genuine zero-result response still lands `.noResults`,
/// and a REST failure with a local ingredient fallback still shows results.
@MainActor
@Suite("SearchViewModel REST failure error state (DUT-622)") struct SearchViewModelDUT622Tests {

    @Test func failedRESTWithNoFallbackSurfacesError() async {
        // Online, REST throws, no local ingredient tier → retryable `.error`
        // (NOT `.noResults`, which reads as "we searched and found nothing").
        let dependencies = FakeSearchDependencies()
        dependencies.online = true
        dependencies.searchShouldThrow = true
        let viewModel = SearchViewModel(dependencies: dependencies, recentSearches: Self.scratchRecents())
        viewModel.query = "pasta"
        await viewModel.runImmediateSearch()
        #expect(viewModel.state == .error)
        #expect(viewModel.items.isEmpty)
    }

    @Test func genuineZeroResultStillLandsNoResults() async {
        // Online, REST succeeds but returns nothing → `.noResults` (unchanged).
        let dependencies = FakeSearchDependencies()
        dependencies.online = true
        let viewModel = SearchViewModel(dependencies: dependencies, recentSearches: Self.scratchRecents())
        viewModel.query = "zzz"
        await viewModel.runImmediateSearch()
        #expect(viewModel.state == .noResults)
    }

    @Test func failedRESTWithLocalIngredientFallbackStaysOnResults() async {
        // REST throws, but the offline ingredient tier has a hit → the user
        // stays on a results screen (DUT-11 resilience), NOT the error screen.
        let dependencies = FakeSearchDependencies()
        dependencies.online = true
        dependencies.searchShouldThrow = true
        dependencies.localIngredientIDs["onion"] = [7]
        dependencies.cachedItemsByID[7] = Self.item(7, title: "Onion Soup")
        let viewModel = SearchViewModel(dependencies: dependencies, recentSearches: Self.scratchRecents())
        viewModel.query = "onion"
        await viewModel.runImmediateSearch()
        #expect(viewModel.state == .results)
        #expect(!viewModel.ingredientItems.isEmpty)
    }

    @Test func retryAfterFailureRecoversToResultsWhenNetworkReturns() async {
        // The failure clears (transient blip); tapping Retry re-runs the query
        // and now lands results — proving `.error` is genuinely recoverable.
        let dependencies = FakeSearchDependencies()
        dependencies.online = true
        dependencies.searchShouldThrow = true
        dependencies.results["pasta"] = [Self.item(1, title: "Pasta")]
        let viewModel = SearchViewModel(dependencies: dependencies, recentSearches: Self.scratchRecents())
        viewModel.query = "pasta"
        await viewModel.runImmediateSearch()
        #expect(viewModel.state == .error)

        dependencies.searchShouldThrow = false
        await viewModel.retrySearch()
        #expect(viewModel.state == .results)
        #expect(viewModel.items.count == 1)
    }

    static func item(_ id: Int, title: String) -> RecipeListItem {
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
        let suiteName = "dod.searchDUT622Tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return RecentSearches(defaults: defaults, storageKey: "recents")
    }
}

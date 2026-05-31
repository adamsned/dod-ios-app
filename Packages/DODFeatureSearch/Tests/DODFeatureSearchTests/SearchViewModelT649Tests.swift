import DODDomain
import DODSupport
import Foundation
import Testing

@testable import DODFeatureSearch

/// L1 coverage for the T-649 / CL-127 "did you mean?" view-model
/// integration. Pure-helper coverage lives in `DODSupportTests`
/// (`SearchSuggestionEngineTests`); this suite pins the wiring:
/// when the gate fires, when it clears, and what `applyDidYouMean()`
/// does to `query` + the banner.
@MainActor
@Suite("SearchViewModel didYouMean (T-649 / CL-127)")
struct SearchViewModelT649Tests {

    @Test func didYouMean_fires_when_results_count_less_than_3() async {
        // Two title-matched results — below the threshold of 3 — and a
        // cached-titles pool that has a closer neighbor to the typo
        // ("naxxos"). The engine must produce a non-nil suggestion the
        // view will render.
        let dependencies = FakeSearchDependencies()
        dependencies.results["naxxos"] = [
            SearchViewModelTests.makeItem(1, title: "Naxxos"),
            SearchViewModelTests.makeItem(2, title: "Naxxos"),
        ]
        dependencies.cachedTitlesArray = [
            "Cast Iron Skillet Nachos",
            "Super Nacho Dip",
            "Loaded Nachos",
        ]
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: SearchViewModelTests.scratchRecents()
        )
        viewModel.query = "naxxos"
        await viewModel.runImmediateSearch()
        #expect(viewModel.items.count == 2, "Fixture under the < 3 threshold")
        #expect(
            viewModel.didYouMean == "nachos",
            "Engine surfaces the closest cached-token neighbor"
        )
    }

    @Test func didYouMean_clears_when_results_count_3_or_more() async {
        // Three title-matched results meets the threshold — the rescue
        // banner is unnecessary. The model must clear any prior
        // suggestion even if the cached-titles pool would have
        // produced one.
        let dependencies = FakeSearchDependencies()
        dependencies.results["nachos"] = [
            SearchViewModelTests.makeItem(1, title: "Nachos"),
            SearchViewModelTests.makeItem(2, title: "Nachos"),
            SearchViewModelTests.makeItem(3, title: "Nachos"),
        ]
        dependencies.cachedTitlesArray = [
            "Cast Iron Skillet Nachos",
            "Super Nacho Dip",
        ]
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: SearchViewModelTests.scratchRecents()
        )
        viewModel.query = "nachos"
        await viewModel.runImmediateSearch()
        #expect(viewModel.items.count == 3, "Threshold met — banner stays away")
        #expect(viewModel.didYouMean == nil, "Threshold met → no banner")
    }

    @Test func applyDidYouMean_updates_query_and_clears_suggestion() async {
        // Seed the same sparse-result fixture so a suggestion lands,
        // then tap-equivalent: `applyDidYouMean()` must overwrite the
        // query with the suggestion and null the banner immediately
        // (the existing debounce + performSearch path takes over after
        // the assignment).
        let dependencies = FakeSearchDependencies()
        dependencies.results["naxxos"] = [
            SearchViewModelTests.makeItem(1, title: "Naxxos")
        ]
        dependencies.cachedTitlesArray = ["Cast Iron Skillet Nachos"]
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: SearchViewModelTests.scratchRecents()
        )
        viewModel.query = "naxxos"
        await viewModel.runImmediateSearch()
        #expect(viewModel.didYouMean == "nachos")

        viewModel.applyDidYouMean()
        #expect(viewModel.query == "nachos", "Tap rewrites the query")
        #expect(viewModel.didYouMean == nil, "Banner clears immediately on tap")
    }
}

import DODDomain
import Foundation
import Testing

@testable import DODFeatureSearch

/// T-779 / DUT-85 — recents are recorded only on a *committed* search (Return /
/// keyboard dismissal), never on the live debounced search. Split from
/// `SearchViewModelTests` so neither suite trips the `type_body_length` cap;
/// reuses that suite's `FakeSearchDependencies`, `scratchRecents()`, `makeItem`.
@MainActor
@Suite("SearchViewModel recents on commit (T-779)") struct SearchViewModelRecentsTests {

    @Test func liveSearchDoesNotRecordUntilCommitted() async {
        let scratch = SearchViewModelTests.scratchRecents()
        let dependencies = FakeSearchDependencies()
        dependencies.results["pizza"] = [SearchViewModelTests.makeItem(1)]
        let viewModel = SearchViewModel(dependencies: dependencies, recentSearches: scratch)
        viewModel.query = "pizza"
        await viewModel.runImmediateSearch()
        // The live search alone records nothing — the bug Spencer reported.
        #expect(viewModel.recentSearches.isEmpty)

        viewModel.commitRecentSearch()
        #expect(viewModel.recentSearches == ["pizza"])
    }

    @Test func commitSkipsCuratedTapsAndShortQueries() async {
        let scratch = SearchViewModelTests.scratchRecents()
        let viewModel = SearchViewModel(
            dependencies: FakeSearchDependencies(),
            recentSearches: scratch
        )
        // Under 2 characters → skipped.
        viewModel.query = "a"
        viewModel.commitRecentSearch()
        #expect(viewModel.recentSearches.isEmpty)
        // Curated "Try" tap → skipped even when committed (REG-19 / CL-66).
        viewModel.selectCuratedSuggestion("Bourbon")
        viewModel.commitRecentSearch()
        #expect(viewModel.recentSearches.isEmpty)
    }
}

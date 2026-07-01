import DODDomain
import DODSupport
import Foundation
import Testing

@testable import DODFeatureSearch

/// H1 (SDET 2026-06-28) — a slow earlier search must not overwrite a faster
/// later one. `performSearch()` stamps a monotonic `searchGeneration`; the
/// finalize hop (`finishTextSearch` → `applyFiltersAndFinalize`) and the lazy
/// hydration tasks bail if a newer search has bumped the generation since they
/// started. Reproduced white-box by driving the finalize hop with a stale token.
@MainActor
@Suite("SearchViewModel search-generation guard (H1)") struct SearchViewModelGenerationTests {

    @Test func staleFinalizeDoesNotOverwriteNewerResults() async {
        let dependencies = FakeSearchDependencies()
        dependencies.results["chicken"] = [Self.makeItem(1, title: "Chicken")]
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )

        viewModel.query = "chicken"
        await viewModel.runImmediateSearch()
        #expect(viewModel.items.map(\.id) == [1])
        let currentGeneration = viewModel.searchGeneration

        // A slow earlier "chick" search finally returns AFTER "chicken" won. Its
        // finalize carries a now-stale generation and must NOT clobber items.
        await viewModel.finishTextSearch(
            merged: [Self.makeItem(2, title: "Chicken Pot Pie")],
            localItems: [],
            trimmed: "chick",
            online: true,
            generation: currentGeneration - 1
        )
        #expect(viewModel.items.map(\.id) == [1])  // still chicken — stale finish bailed

        // The guard isn't over-eager: a finalize at the CURRENT generation applies.
        await viewModel.finishTextSearch(
            merged: [Self.makeItem(2, title: "Chicken Pot Pie")],
            localItems: [],
            trimmed: "chicken",
            online: true,
            generation: currentGeneration
        )
        #expect(viewModel.items.map(\.id) == [2])
    }

    /// DUT-221: tapping Clear (X) while a query is still in flight must not let
    /// that slow query repaint its results over the now-idle screen. `clear()`
    /// bumps the generation, so a finalize carrying the pre-clear token bails.
    @Test func clearMakesInFlightSearchBailInsteadOfRepainting() async {
        let dependencies = FakeSearchDependencies()
        dependencies.results["chicken"] = [Self.makeItem(1, title: "Chicken")]
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )

        viewModel.query = "chicken"
        await viewModel.runImmediateSearch()
        // A search is conceptually in flight at this generation.
        let inFlightGeneration = viewModel.searchGeneration

        // User taps Clear before the slow query returns.
        viewModel.clear()
        #expect(viewModel.state == .idle)
        #expect(viewModel.items.isEmpty)

        // The slow query now returns; its finalize must NOT repaint over idle.
        await viewModel.finishTextSearch(
            merged: [Self.makeItem(9, title: "Chicken Soup")],
            localItems: [],
            trimmed: "chicken",
            online: true,
            generation: inFlightGeneration
        )
        #expect(viewModel.state == .idle)
        #expect(viewModel.items.isEmpty)
    }

    static func makeItem(_ id: Int, title: String) -> RecipeListItem {
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
        let suiteName = "dod.searchGenTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return RecentSearches(defaults: defaults, storageKey: "recents")
    }
}

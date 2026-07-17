import DODDomain
import Foundation
import Testing

@testable import DODFeatureSearch

/// v2 Search overhaul (1/3) — "Surprise Me" moved OFF the Feed header and ONTO
/// the Search page's idle state. `SearchViewModel.surpriseMe(onSelect:)` is a
/// thin wrapper over `dependencies.fetchRandomRecipe()` (full-catalog
/// `orderby=rand`) with an in-memory `RandomRecipePicker` fallback; it mirrors
/// `FeedViewModel.surpriseMe(onSelect:)` one-to-one.
@MainActor
@Suite("SearchViewModel surpriseMe (v2 Search overhaul 1/3)")
struct SearchViewModelSurpriseMeTests {

    private static func makeItem(_ id: Int) -> RecipeListItem {
        RecipeListItem(
            id: id,
            title: "Recipe \(id)",
            excerpt: "Excerpt",
            heroImage: nil,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            totalTimeDisplay: nil
        )
    }

    @Test func fetches_a_random_recipe_and_hands_it_to_on_select() async {
        let deps = FakeSearchDependencies()
        deps.randomRecipe = Self.makeItem(42)
        let viewModel = SearchViewModel(dependencies: deps)

        var selected: RecipeListItem?
        await viewModel.surpriseMe { selected = $0 }

        #expect(selected?.id == 42)
        #expect(viewModel.lastSurpriseID == 42)
        #expect(viewModel.isSurpriseMeLoading == false)
    }

    // When the full-catalog fetch throws (offline / server error) AND there are
    // no in-memory results to sample, `surpriseMe` is a no-op (the idle page
    // has no `items` before a query runs).
    @Test func fetch_failure_with_no_items_is_a_no_op() async {
        let deps = FakeSearchDependencies()
        deps.randomShouldThrow = true
        let viewModel = SearchViewModel(dependencies: deps)

        var selected: RecipeListItem?
        await viewModel.surpriseMe { selected = $0 }

        #expect(selected == nil)
        #expect(viewModel.lastSurpriseID == nil)
        #expect(viewModel.isSurpriseMeLoading == false)
    }

    // Re-entrancy: a second tap arriving while the first fetch is still in
    // flight is dropped (guarded by `isSurpriseMeLoading`).
    @Test func concurrent_second_tap_is_dropped_while_a_fetch_is_in_flight() async {
        let deps = FakeSearchDependencies()
        deps.randomRecipe = Self.makeItem(7)
        let release = AsyncGate()
        deps.randomGate = { await release.wait() }
        let viewModel = SearchViewModel(dependencies: deps)

        var firstSelected: RecipeListItem?
        let firstTask = Task { await viewModel.surpriseMe { firstSelected = $0 } }
        // Deterministically wait until the first tap has parked in the gate
        // (reusing the shared `AsyncGate` helper from the shopping-list suite).
        await release.waitUntilWaiting()

        // Second tap while the first is suspended in the gate — must be dropped.
        var secondSelected: RecipeListItem?
        await viewModel.surpriseMe { secondSelected = $0 }
        #expect(secondSelected == nil, "the in-flight guard should drop the concurrent second tap")

        await release.open()
        await firstTask.value
        #expect(firstSelected?.id == 7)
        #expect(deps.randomRecipeCallCount == 1, "only the first tap should reach the network")
    }
}

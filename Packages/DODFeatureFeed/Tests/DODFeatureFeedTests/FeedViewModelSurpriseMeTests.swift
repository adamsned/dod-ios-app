import DODDomain
import DODSupport
import Foundation
import Testing

@testable import DODFeatureFeed

/// DUT-939 — "Surprise Me" (Android parity: Android already ships a
/// random-recipe entry point, iOS didn't). `surpriseMe(onSelect:)` is a thin
/// wrapper over `RandomRecipePicker` (see `RandomRecipePickerTests` for the
/// picker's own exhaustive coverage) — these tests only check the wiring:
/// no-op on an empty feed, the callback fires with a genuine loaded item, and
/// `lastSurpriseID` advances so a back-to-back tap doesn't repeat.
@MainActor
@Suite("FeedViewModel surpriseMe (DUT-939)") struct FeedViewModelSurpriseMeTests {

    @Test func noOpWhenTheFeedHasNoItems() async {
        let dependencies = FakeFeedDependencies()
        let viewModel = FeedViewModel(dependencies: dependencies)
        var selected: RecipeListItem?
        await viewModel.surpriseMe { selected = $0 }
        #expect(selected == nil)
        #expect(viewModel.lastSurpriseID == nil)
    }

    // DUT-1062: these fallback-path tests all leave `randomRecipeToReturn`
    // nil, so `fetchRandomRecipe()` throws and `surpriseMe` falls through to
    // the pre-DUT-1062 in-memory sample — preserving this suite's original
    // coverage of that path unchanged.

    @Test func picksALoadedItemAndInvokesTheCallback() async throws {
        let dependencies = FakeFeedDependencies()
        dependencies.pages[1] = (1...20).map(Self.makeItem)
        let viewModel = FeedViewModel(dependencies: dependencies)
        await viewModel.onAppear()

        var selected: RecipeListItem?
        await viewModel.surpriseMe { selected = $0 }

        let picked = try #require(selected)
        #expect(viewModel.items.map(\.id).contains(picked.id))
        #expect(viewModel.lastSurpriseID == picked.id)
    }

    @Test func neverRepeatsTheImmediatelyPriorPickWhenMoreThanOneItemExists() async throws {
        let dependencies = FakeFeedDependencies()
        dependencies.pages[1] = (1...20).map(Self.makeItem)
        let viewModel = FeedViewModel(dependencies: dependencies)
        await viewModel.onAppear()

        var previous: Int?
        for _ in 0..<25 {
            var selected: RecipeListItem?
            await viewModel.surpriseMe { selected = $0 }
            let picked = try #require(selected)
            if let previous {
                #expect(picked.id != previous, "back-to-back Surprise Me taps must not repeat")
            }
            previous = picked.id
        }
    }

    @Test func singleItemFeedAlwaysPicksThatItem() async throws {
        let dependencies = FakeFeedDependencies()
        dependencies.pages[1] = [Self.makeItem(42)]
        let viewModel = FeedViewModel(dependencies: dependencies)
        await viewModel.onAppear()

        // First call: pick the only item
        var firstSelected: RecipeListItem?
        await viewModel.surpriseMe { firstSelected = $0 }
        let firstPicked = try #require(firstSelected)
        #expect(firstPicked.id == 42)
        #expect(viewModel.lastSurpriseID == 42)

        // Second call: with lastSurpriseID=42, should still pick it (only option)
        var secondSelected: RecipeListItem?
        await viewModel.surpriseMe { secondSelected = $0 }
        let secondPicked = try #require(secondSelected)
        #expect(secondPicked.id == 42)
        #expect(viewModel.lastSurpriseID == 42, "lastSurpriseID should remain unchanged for single-item feed")
    }

    // MARK: - DUT-1062: full-catalog network path

    /// The whole point of the fix: a successful `fetchRandomRecipe()` can
    /// (and, for a small loaded page, typically will) surface a recipe id
    /// that was never paged into `items` at all — proving the sample now
    /// spans the full catalog, not just what's been scrolled to.
    @Test func picksAFullCatalogRecipeBeyondTheLoadedFeedWhenTheNetworkFetchSucceeds() async {
        let dependencies = FakeFeedDependencies()
        dependencies.pages[1] = (1...20).map(Self.makeItem)
        dependencies.randomRecipeToReturn = Self.makeItem(9999)
        let viewModel = FeedViewModel(dependencies: dependencies)
        await viewModel.onAppear()

        var selected: RecipeListItem?
        await viewModel.surpriseMe { selected = $0 }

        #expect(selected?.id == 9999)
        #expect(
            !viewModel.items.map(\.id).contains(9999),
            "9999 must be outside the loaded feed for this to prove anything"
        )
        #expect(viewModel.lastSurpriseID == 9999)
        #expect(viewModel.isSurpriseMeLoading == false)
        #expect(dependencies.randomRecipeCallCount == 1)
    }

    /// The button must never go dead offline: a failed full-catalog fetch
    /// falls back to the DUT-939 in-memory sample instead of no-opping.
    @Test func fallsBackToTheInMemorySampleWhenTheNetworkFetchFails() async throws {
        let dependencies = FakeFeedDependencies()
        dependencies.pages[1] = (1...20).map(Self.makeItem)
        // randomRecipeToReturn left nil -> fetchRandomRecipe() throws.
        let viewModel = FeedViewModel(dependencies: dependencies)
        await viewModel.onAppear()

        var selected: RecipeListItem?
        await viewModel.surpriseMe { selected = $0 }

        let picked = try #require(selected)
        #expect(viewModel.items.map(\.id).contains(picked.id))
        #expect(viewModel.isSurpriseMeLoading == false)
        #expect(dependencies.randomRecipeCallCount == 1)
    }

    /// A second tap arriving while the first fetch is still in flight must
    /// be dropped, not spawn a second overlapping fetch. Uses the fake's
    /// gate to hold the first `fetchRandomRecipe()` in flight, deterministically
    /// (no polling/sleeping) synchronizing on `randomRecipeGateReached`.
    @Test func reentrantTapWhileAFetchIsInFlightIsANoOp() async {
        let dependencies = FakeFeedDependencies()
        dependencies.pages[1] = (1...20).map(Self.makeItem)
        dependencies.randomRecipeToReturn = Self.makeItem(9999)
        dependencies.randomRecipeShouldGate = true
        let viewModel = FeedViewModel(dependencies: dependencies)
        await viewModel.onAppear()

        var firstSelected: RecipeListItem?
        // Start the first tap's fetch and wait (via the gate callback, not
        // polling/sleeping) until it's actually suspended inside
        // `fetchRandomRecipe` — i.e. `isSurpriseMeLoading` is already true —
        // before firing the reentrant second tap.
        let firstTask = Task { await viewModel.surpriseMe { firstSelected = $0 } }
        await withCheckedContinuation { continuation in
            dependencies.randomRecipeGateReached = { continuation.resume() }
        }
        #expect(viewModel.isSurpriseMeLoading)

        var secondSelected: RecipeListItem?
        await viewModel.surpriseMe { secondSelected = $0 }
        #expect(secondSelected == nil, "a reentrant tap mid-fetch must no-op")

        dependencies.openRandomRecipeGate()
        await firstTask.value
        #expect(firstSelected?.id == 9999)
        #expect(dependencies.randomRecipeCallCount == 1, "the reentrant tap must not have started a second fetch")
    }

    static func makeItem(_ id: Int) -> RecipeListItem {
        RecipeListItem(
            id: id,
            title: "Recipe \(id)",
            excerpt: "Excerpt \(id)",
            heroImage: URL(string: "https://example.com/\(id).jpg"),
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            totalTimeDisplay: nil
        )
    }
}

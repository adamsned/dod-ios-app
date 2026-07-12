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

    @Test func noOpWhenTheFeedHasNoItems() {
        let dependencies = FakeFeedDependencies()
        let viewModel = FeedViewModel(dependencies: dependencies)
        var selected: RecipeListItem?
        viewModel.surpriseMe { selected = $0 }
        #expect(selected == nil)
        #expect(viewModel.lastSurpriseID == nil)
    }

    @Test func picksALoadedItemAndInvokesTheCallback() async throws {
        let dependencies = FakeFeedDependencies()
        dependencies.pages[1] = (1...20).map(Self.makeItem)
        let viewModel = FeedViewModel(dependencies: dependencies)
        await viewModel.onAppear()

        var selected: RecipeListItem?
        viewModel.surpriseMe { selected = $0 }

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
            viewModel.surpriseMe { selected = $0 }
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
        viewModel.surpriseMe { firstSelected = $0 }
        let firstPicked = try #require(firstSelected)
        #expect(firstPicked.id == 42)
        #expect(viewModel.lastSurpriseID == 42)

        // Second call: with lastSurpriseID=42, should still pick it (only option)
        var secondSelected: RecipeListItem?
        viewModel.surpriseMe { secondSelected = $0 }
        let secondPicked = try #require(secondSelected)
        #expect(secondPicked.id == 42)
        #expect(viewModel.lastSurpriseID == 42, "lastSurpriseID should remain unchanged for single-item feed")
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

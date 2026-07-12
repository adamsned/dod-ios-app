import DODDomain
import DODNetworking
import Foundation
import Testing

@testable import DODFeatureCategories

/// Async-state tests covering genuine gaps in CategoryRecipesViewModel coverage:
/// retry() haptic gating, loadMoreIfNeeded guard conditions, and append de-duplication.
@MainActor
@Suite("CategoryRecipesViewModel async-state gaps")
struct CategoryRecipesViewModelGapTests {

    @Test func retrySuccessBumpsRefreshCount() async {
        // DUT-693 (PR6): `retry()` calls `load()` which has `@discardableResult`.
        // On a clean fetch, `retry()` bumps `refreshCount` via the Bool return
        // of `load()`. A failed retry leaves `refreshCount` untouched.
        let dependencies = FakeCategoriesDependencies()
        dependencies.failOnPage = 1
        let category = DODDomain.Category(id: 336, name: "Desserts", slug: "desserts", count: 5)
        let viewModel = CategoryRecipesViewModel(category: category, dependencies: dependencies)
        await viewModel.onAppear()
        #expect(viewModel.loadState == .offline)
        #expect(viewModel.refreshCount == 0)

        // Reconnect and retry: clear the failure and seed page 1.
        dependencies.failOnPage = nil
        dependencies.posts[1] = (1...5).map(Self.makeItem)
        await viewModel.retry()
        #expect(viewModel.items.count == 5)
        #expect(viewModel.loadState == .loaded)
        #expect(viewModel.refreshCount == 1)  // bumped on successful retry
    }

    @Test func retryFailureKeepsRefreshCountUnchanged() async {
        // DUT-693 (PR6): a failed `retry()` does NOT bump `refreshCount`
        // (no reward for failure). The `load()` Bool return gates this.
        let dependencies = FakeCategoriesDependencies()
        dependencies.errorForPage1 = WPClientError.httpStatus(500)
        dependencies.failOnPage = 1
        let category = DODDomain.Category(id: 336, name: "Desserts", slug: "desserts", count: 5)
        let viewModel = CategoryRecipesViewModel(category: category, dependencies: dependencies)
        await viewModel.onAppear()
        #expect(viewModel.loadState == .error)
        #expect(viewModel.refreshCount == 0)

        // Retry while still offline: still fails, refreshCount stays 0.
        await viewModel.retry()
        #expect(viewModel.loadState == .error)
        #expect(viewModel.refreshCount == 0)  // NOT bumped on failed retry
    }

    @Test func loadMoreIfNeededWithItemNotInLastThreeIsNoOp() async throws {
        // The guard at line 123-127 checks multiple conditions; one is that the
        // currentItem must be in the last 3. A call with an item early in the
        // grid is a no-op — no page-2 fetch.
        let dependencies = FakeCategoriesDependencies()
        dependencies.posts[1] = (1...20).map(Self.makeItem)
        dependencies.posts[2] = (21...40).map(Self.makeItem)
        dependencies.totalPagesOverride = 2
        let category = DODDomain.Category(id: 336, name: "Desserts", slug: "desserts", count: 40)
        let viewModel = CategoryRecipesViewModel(category: category, dependencies: dependencies)
        await viewModel.onAppear()
        #expect(viewModel.items.count == 20)

        // Call with item[5] (definitely not in last 3).
        let midItem = viewModel.items[5]
        await viewModel.loadMoreIfNeeded(currentItem: midItem)
        // No page 2 should have been fetched.
        #expect(dependencies.fetchedPages == [1])
        #expect(viewModel.items.count == 20)
    }

    @Test func loadMoreIfNeededWhenReachedEndIsNoOp() async throws {
        // The guard at line 124 checks `!reachedEnd`. When pagination has
        // reached the last page, `loadMoreIfNeeded` on any item is a no-op.
        let dependencies = FakeCategoriesDependencies()
        dependencies.posts[1] = (1...20).map(Self.makeItem)
        dependencies.totalPagesOverride = 1  // Only 1 page total
        let category = DODDomain.Category(id: 336, name: "Desserts", slug: "desserts", count: 20)
        let viewModel = CategoryRecipesViewModel(category: category, dependencies: dependencies)
        await viewModel.onAppear()
        #expect(viewModel.items.count == 20)
        // After the initial load with totalPages=1, reachedEnd is true.

        // Try to load more on the last item.
        let lastItem = try #require(viewModel.items.last)
        await viewModel.loadMoreIfNeeded(currentItem: lastItem)
        // No page 2 should have been fetched.
        #expect(dependencies.fetchedPages == [1])
        #expect(viewModel.items.count == 20)
    }

    @Test func appendDeDeduplicatesAlreadyLoadedItems() async throws {
        // The append branch (lines 170-171) filters fetched items against the
        // already-loaded grid using a `seen` set. If page 2 returns items that
        // are already in the grid, they should be dropped — no duplicate cards.
        let dependencies = FakeCategoriesDependencies()
        dependencies.posts[1] = (1...20).map(Self.makeItem)
        dependencies.posts[2] = (15...24).map(Self.makeItem)  // ids 15-20 overlap with page 1
        dependencies.totalPagesOverride = 2
        let category = DODDomain.Category(id: 336, name: "Desserts", slug: "desserts", count: 30)
        let viewModel = CategoryRecipesViewModel(category: category, dependencies: dependencies)
        await viewModel.onAppear()
        #expect(viewModel.items.count == 20)

        // Load page 2; the 6 overlapping items (15-20) should be filtered out.
        let lastItem = try #require(viewModel.items.last)
        await viewModel.loadMoreIfNeeded(currentItem: lastItem)
        // Page 2 has 15-24 (10 items), page 1 has 1-20 (20 items).
        // Overlap: 15-20 (6 items). So new items: 21-24 (4 items). Total: 20 + 4 = 24.
        #expect(viewModel.items.count == 24)

        // Verify no duplicate ids in the final list.
        let ids = Set(viewModel.items.map(\.id))
        #expect(ids.count == 24)
    }

    static func makeItem(_ id: Int) -> RecipeListItem {
        RecipeListItem(
            id: id,
            title: "R\(id)",
            excerpt: "e",
            heroImage: nil,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            totalTimeDisplay: nil
        )
    }
}

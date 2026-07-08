import DODDomain
import DODNetworking
import Foundation
import Testing

@testable import DODFeatureCategories

/// DUT-706 — a pull-to-refresh must not race a near-bottom load-more.
/// `refresh()` calls `load(page: 1, keepStateWhilePopulated: true)`, which keeps
/// `loadState == .loaded` while it awaits the network (so the populated grid
/// stays on screen under the system spinner). Because `CategoryRecipesView`
/// wires both `.refreshable { refresh() }` and a per-row `.task {
/// loadMoreIfNeeded(...) }`, a card near the bottom could fire a concurrent
/// `load(page: 2, append: true)` while the refresh was in flight — and if the
/// page-1 refresh resolved last it rewound `currentPage` to 1 and reset `items`
/// to the page-1 set, vanishing already-shown recipes and re-fetching page 2.
///
/// The fix mirrors `FeedViewModel`'s DUT-382 latch: `load` sets
/// `isLoadInFlight = true` before its first `await` (with `defer` to clear it),
/// and `loadMoreIfNeeded` bails while it's set. This drives the race
/// deterministically with the `FakeCategoriesDependencies` per-page gate: a
/// refresh (page 1) is parked at its `fetchPosts` and, while it's in flight, a
/// `loadMoreIfNeeded` is invoked and must no-op — never touching page 2.
@MainActor
@Suite("CategoryRecipesViewModel refresh vs load-more race (DUT-706)")
struct CategoryRecipesRefreshRaceTests {

    @Test func loadMoreNoOpsWhileRefreshInFlight() async throws {
        let dependencies = FakeCategoriesDependencies()
        dependencies.posts[1] = (1...20).map(Self.makeItem)
        dependencies.posts[2] = (21...40).map(Self.makeItem)  // a leaking loadMore would append these
        dependencies.totalPagesOverride = 3
        let category = DODDomain.Category(id: 9, name: "Big", slug: "big", count: 60)
        let viewModel = CategoryRecipesViewModel(category: category, dependencies: dependencies)
        await viewModel.onAppear()
        #expect(viewModel.items.map(\.id) == Array(1...20))
        #expect(viewModel.loadState == .loaded)

        // Arm the page-1 gate and start a pull-to-refresh that parks at
        // `fetchPosts(page: 1)`. Capturing the Task handle lets us `await` it to
        // completion later without timing guesses; we first await the signal that
        // it actually reached the gate, so the load-more below is guaranteed to
        // interleave with a genuinely in-flight refresh.
        dependencies.armGate(page: 1)
        let refreshTask = Task { await viewModel.refresh() }
        await withCheckedContinuation { reached in
            dependencies.gateReached = { @Sendable page in
                if page == 1 { reached.resume() }
            }
        }

        // The refresh is now suspended mid-flight: `isLoadInFlight` is set and
        // (keepStateWhilePopulated) the grid is still `.loaded`. A near-bottom
        // card firing its load-more `.task` must be a no-op — NOT a concurrent
        // `load(page: 2, append: true)`.
        let last = try #require(viewModel.items.last)  // id 20 — in the last 3
        await viewModel.loadMoreIfNeeded(currentItem: last)
        #expect(
            !dependencies.fetchedPages.contains(2),
            "load-more must not fetch page 2 while a refresh is in flight"
        )
        #expect(viewModel.items.map(\.id) == Array(1...20))
        #expect(viewModel.loadState == .loaded)

        // Release the refresh and join it. It commits the refreshed page-1 set and
        // rewinds the cursor to 1 — cleanly, because no stale page-2 append ran.
        dependencies.openGate(page: 1)
        await refreshTask.value
        #expect(viewModel.items.map(\.id) == Array(1...20))
        #expect(viewModel.loadState == .loaded)

        // The cursor reflects the refresh (page 1), so paginating once now fetches
        // page 2 exactly once — proving state ended consistent.
        let last2 = try #require(viewModel.items.last)
        await viewModel.loadMoreIfNeeded(currentItem: last2)
        #expect(viewModel.items.map(\.id) == Array(1...40))
        #expect(dependencies.fetchedPages.filter { $0 == 2 }.count == 1)
    }

    @Test func normalLoadMoreStillAppendsWhenNoRefreshInFlight() async throws {
        // Control: the `isLoadInFlight` latch must not swallow a legitimate
        // load-more when nothing is racing it — pagination still advances.
        let dependencies = FakeCategoriesDependencies()
        dependencies.posts[1] = (1...20).map(Self.makeItem)
        dependencies.posts[2] = (21...40).map(Self.makeItem)
        dependencies.posts[3] = (41...60).map(Self.makeItem)
        dependencies.totalPagesOverride = 3
        let category = DODDomain.Category(id: 9, name: "Big", slug: "big", count: 60)
        let viewModel = CategoryRecipesViewModel(category: category, dependencies: dependencies)
        await viewModel.onAppear()
        #expect(viewModel.items.map(\.id) == Array(1...20))

        var last = try #require(viewModel.items.last)
        await viewModel.loadMoreIfNeeded(currentItem: last)  // -> page 2
        #expect(viewModel.items.map(\.id) == Array(1...40))

        last = try #require(viewModel.items.last)
        await viewModel.loadMoreIfNeeded(currentItem: last)  // -> page 3
        #expect(viewModel.items.map(\.id) == Array(1...60))
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

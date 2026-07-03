import DODDomain
import DODSupport
import Foundation
import Testing

@testable import DODFeatureFeed

/// DUT-511 — a pull-to-refresh must not be clobbered by an in-flight
/// `loadMore` that resumes after it. `refresh()` calls
/// `loadInitial(forceReplace:)` unconditionally; before the fix it neither
/// checked the DUT-382 `isLoading` latch nor cancelled/awaited a running
/// `loadMore`. Because everything is `@MainActor`, a `loadMore` suspended at
/// `fetchPosts`/`cachedListItems` could resume AFTER `loadInitial` committed
/// page 1 and overwrite `items`/`currentPage`/`reachedEnd` with stale page-2
/// data (duplicate/stale rows + a wrong page cursor).
///
/// The fix stamps a monotonic `loadGeneration` at the start of `loadInitial`
/// and `loadMore` (mirroring `SearchViewModel.searchGeneration`) and re-checks
/// it after every `await` before committing state. `refresh()` starting a
/// `loadInitial` bumps the generation, so the superseded `loadMore` fails its
/// post-await guard and no-ops.
///
/// These tests drive the race deterministically with `FakeFeedDependencies`'s
/// per-page gate: a `loadMore` (page 2) is held at its `fetchPosts` until a
/// `refresh()` (page 1) has fully committed, then released.
@MainActor
@Suite("FeedViewModel refresh vs in-flight loadMore (DUT-511)")
struct FeedViewModelRefreshRaceTests {

    @Test func refreshIsNotClobberedByInFlightLoadMore() async throws {
        let dependencies = FakeFeedDependencies()
        dependencies.pages[1] = (1...20).map(Self.makeItem)
        dependencies.pages[2] = (21...40).map(Self.makeItem)
        dependencies.totalPagesOverride = 3
        let viewModel = FeedViewModel(dependencies: dependencies)
        await viewModel.onAppear()
        #expect(viewModel.items.map(\.id) == Array(1...20))

        // Arm the page-2 gate and start a `loadMore` that will park at
        // `fetchPosts(page: 2)`. Capturing the Task handle lets us `await` the
        // resumed load to completion later without timing guesses. We first
        // await a signal that it actually reached the gate, so the refresh below
        // is guaranteed to interleave with a genuinely in-flight `loadMore`.
        dependencies.armGate(page: 2)
        let last0 = try #require(viewModel.items.last)
        let loadMoreTask = Task { await viewModel.loadMoreIfNeeded(currentItem: last0) }
        await withCheckedContinuation { reached in
            // `gateReached` fires from inside `fetchPosts(page: 2)`, i.e. once the
            // just-started `loadMore` has actually parked at the gate.
            dependencies.gateReached = { @Sendable page in
                if page == 2 { reached.resume() }
            }
        }

        // The page-2 `loadMore` is now suspended mid-flight. Run a full
        // pull-to-refresh (page 1) to completion — it bumps the generation and
        // commits the refreshed page-1 set.
        await viewModel.refresh()
        #expect(viewModel.items.map(\.id) == Array(1...20))

        // Release the held `loadMore` and join it. Its post-await generation
        // guard now fails, so it must drop its stale page-2 writes instead of
        // clobbering the refreshed list or rewinding the page cursor. Against the
        // pre-fix code the join lands the stale write and `items` grows to 40.
        dependencies.openGate(page: 2)
        await loadMoreTask.value

        #expect(
            viewModel.items.map(\.id) == Array(1...20),
            "the stale loadMore must not re-append page 2 over the refreshed feed"
        )
        // The cursor must reflect the refresh (page 1), not the stale page-2
        // load. Prove it by paginating once: the next page fetched is page 2.
        let last = try #require(viewModel.items.last)
        await viewModel.loadMoreIfNeeded(currentItem: last)
        #expect(
            viewModel.items.map(\.id) == Array(1...40),
            "currentPage was rewound to 1 by the refresh, so the next page is 2"
        )
    }

    @Test func normalLoadMoreStillAppendsAndAdvancesCursor() async throws {
        // Control: with no refresh interleaving, `loadMore` still appends the
        // next page and advances the cursor — the generation guard must not
        // swallow legitimate current-generation writes.
        let dependencies = FakeFeedDependencies()
        dependencies.pages[1] = (1...20).map(Self.makeItem)
        dependencies.pages[2] = (21...40).map(Self.makeItem)
        dependencies.pages[3] = (41...60).map(Self.makeItem)
        dependencies.totalPagesOverride = 3
        let viewModel = FeedViewModel(dependencies: dependencies)
        await viewModel.onAppear()
        #expect(viewModel.items.map(\.id) == Array(1...20))

        var last = try #require(viewModel.items.last)
        await viewModel.loadMoreIfNeeded(currentItem: last)  // -> page 2
        #expect(viewModel.items.map(\.id) == Array(1...40))

        last = try #require(viewModel.items.last)
        await viewModel.loadMoreIfNeeded(currentItem: last)  // -> page 3 (cursor advanced)
        #expect(viewModel.items.map(\.id) == Array(1...60))
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

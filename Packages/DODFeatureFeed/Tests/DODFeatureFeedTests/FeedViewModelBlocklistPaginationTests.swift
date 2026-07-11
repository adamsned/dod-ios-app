import DODDomain
import DODSupport
import Foundation
import Testing

@testable import DODFeatureFeed

/// A blocklist can filter a fetched page down to zero VISIBLE items (e.g. a
/// batch report/hide) even though the raw page wasn't empty and more pages
/// remain (`X-WP-TotalPages`). `loadMore` already tolerates this for page 2+
/// (it just advances the cursor and stays `.loaded`); `loadInitial`'s first
/// page must not dead-end into the `.empty` "No recipes" state while real
/// content sits one page away — it should keep paging until a page yields
/// visible items or it genuinely reaches the real last page. Split into its
/// own file (mirroring `FeedViewModelRefreshRaceTests`) to keep
/// `FeedViewModelTests` under the SwiftLint `file_length` cap.
@MainActor
@Suite("FeedViewModel first-page blocklist wipeout")
struct FeedViewModelBlocklistPaginationTests {

    @Test func firstPageEntirelyBlocklistedContinuesToNextPageInsteadOfShowingEmpty() async throws {
        let dependencies = FakeFeedDependencies()
        dependencies.pages[1] = (1...5).map(Self.makeItem)
        dependencies.pages[2] = (6...10).map(Self.makeItem)
        dependencies.totalPagesOverride = 2
        for id in 1...5 { dependencies.blocklistedIDs.insert(id) }
        let viewModel = FeedViewModel(dependencies: dependencies)
        await viewModel.onAppear()
        #expect(
            viewModel.loadState == .loaded,
            "must not dead-end into .empty when a later page has visible items"
        )
        #expect(viewModel.items.map(\.id) == Array(6...10))
    }

    /// The genuine zero-result case still holds: when EVERY page is filtered to
    /// zero visible items, the feed correctly lands on `.empty` once it has
    /// exhausted every page, rather than looping forever.
    @Test func everyPageEntirelyBlocklistedEventuallyShowsEmpty() async throws {
        let dependencies = FakeFeedDependencies()
        dependencies.pages[1] = (1...5).map(Self.makeItem)
        dependencies.pages[2] = (6...10).map(Self.makeItem)
        dependencies.totalPagesOverride = 2
        for id in 1...10 { dependencies.blocklistedIDs.insert(id) }
        let viewModel = FeedViewModel(dependencies: dependencies)
        await viewModel.onAppear()
        #expect(viewModel.loadState == .empty)
        #expect(viewModel.items.isEmpty)
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

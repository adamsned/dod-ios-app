import DODDomain
import DODSupport
import Foundation
import Observation

/// State + paging logic for the home feed.
///
/// Spec trace: AC-1.1, AC-1.2, AC-1.4, AC-1.5, AC-1.6, AC-1.7.
@Observable
@MainActor
public final class FeedViewModel {

    public enum LoadState: Equatable {
        case idle
        case loadingInitial
        case loaded
        case loadingMore
        case empty
        case firstLaunchOffline
    }

    public private(set) var items: [RecipeListItem] = []
    public private(set) var loadState: LoadState = .idle
    public private(set) var isOffline: Bool = false
    public private(set) var errorMessage: String?
    /// Bumped after every successful pull-to-refresh so the view can fire a
    /// `.sensoryFeedback(.success, trigger:)` haptic. Not part of any AC —
    /// purely UX polish (iOS 17 sensoryFeedback wiring).
    public private(set) var refreshCount: Int = 0

    private let dependencies: FeedDependencies
    private var currentPage: Int = 0
    private var reachedEnd: Bool = false
    /// `nonisolated(unsafe)` so `deinit` can cancel without main-actor hop;
    /// Task is Sendable and deinit fires exactly once.
    nonisolated(unsafe) private var connectivityTask: Task<Void, Never>?

    private static let listKey = "home"

    public init(dependencies: FeedDependencies) {
        self.dependencies = dependencies
    }

    deinit {
        connectivityTask?.cancel()
    }

    /// Called when the feed view first appears.
    public func onAppear() async {
        // Subscribe once.
        if connectivityTask == nil {
            connectivityTask = Task { [weak self] in
                guard let self else { return }
                let stream = await dependencies.connectivityChanges()
                for await isOnline in stream {
                    await self.handleConnectivity(isOnline: isOnline)
                }
            }
        }
        if items.isEmpty {
            await loadInitial()
        }
    }

    /// Pull-to-refresh (AC-1.4 + clears blocklist per AC-1.7).
    public func refresh() async {
        try? await dependencies.clearBlocklist()
        await loadInitial(forceReplace: true)
        // Bump only on a clean refresh — error/offline paths set errorMessage
        // and shouldn't reward the user with a success haptic.
        if errorMessage == nil {
            refreshCount &+= 1
        }
    }

    /// Infinite-scroll trigger when a near-bottom row appears (AC-1.2).
    public func loadMoreIfNeeded(currentItem: RecipeListItem) async {
        guard !reachedEnd,
            loadState != .loadingMore,
            loadState != .loadingInitial,
            let lastFew = items.suffix(3).first(where: { $0.id == currentItem.id }) ?? items.last,
            lastFew.id == currentItem.id
        else { return }
        await loadMore()
    }

    // MARK: - Private

    private func loadInitial(forceReplace: Bool = false) async {
        loadState = .loadingInitial
        errorMessage = nil
        currentPage = 0
        reachedEnd = false
        do {
            let fetched = try await dependencies.fetchPosts(page: 1)
            try await dependencies.cache(listItems: fetched)
            items = try await dependencies.cachedListItems(forIDs: fetched.map(\.id))
            currentPage = 1
            loadState = items.isEmpty ? .empty : .loaded
            if fetched.count < 20 { reachedEnd = true }
        } catch {
            DODLog.network.error("feed initial load failed: \(String(describing: error))")
            // Offline-with-cache (AC-1.6) vs first-launch-offline (AC-1.5):
            // attempt to hydrate from cache. If empty, treat as first launch.
            if !forceReplace, let hydrated = await hydratedFromCache(), !hydrated.isEmpty {
                items = hydrated
                isOffline = true
                loadState = .loaded
                return
            }
            isOffline = await !dependencies.isOnline()
            loadState = isOffline ? .firstLaunchOffline : .empty
            errorMessage = "Couldn't load recipes."
        }
    }

    private func loadMore() async {
        loadState = .loadingMore
        let nextPage = currentPage + 1
        do {
            let fetched = try await dependencies.fetchPosts(page: nextPage)
            try await dependencies.cache(listItems: fetched)
            let ids = (items.map(\.id) + fetched.map(\.id)).reduce(into: [Int]()) { acc, id in
                if !acc.contains(id) { acc.append(id) }
            }
            items = try await dependencies.cachedListItems(forIDs: ids)
            currentPage = nextPage
            if fetched.count < 20 { reachedEnd = true }
            loadState = .loaded
        } catch {
            DODLog.network.error("feed loadMore failed: \(String(describing: error))")
            loadState = .loaded  // Keep what we have; show no error toast for tail-pagination failures.
            reachedEnd = true
        }
    }

    private func hydratedFromCache() async -> [RecipeListItem]? {
        // Without a stored list-page key (see FeedDependencies note), we
        // currently can't know *which* ids belonged to the home feed page.
        // For v1 we surface an empty hydration; saved recipes still work
        // via the Saved tab. AC-1.6 hydration improves once T-091/T-101
        // start populating CachedListPage. Returning nil falls through to
        // the first-launch-offline path.
        nil
    }

    private func handleConnectivity(isOnline: Bool) async {
        self.isOffline = !isOnline
        // When connectivity returns and we showed first-launch-offline,
        // try to fetch automatically.
        if isOnline, loadState == .firstLaunchOffline {
            await loadInitial(forceReplace: true)
        }
    }
}

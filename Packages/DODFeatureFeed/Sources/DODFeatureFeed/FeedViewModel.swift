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
        /// DUT-621 — an ONLINE first-launch fetch that failed (server / decode
        /// error, not connectivity). Distinct from `.empty` (a genuine
        /// zero-result success) so the view can offer a failure message + a
        /// Retry action instead of a dead-end "No recipes."
        case firstLaunchFailed
    }

    public private(set) var items: [RecipeListItem] = []
    public private(set) var loadState: LoadState = .idle
    public private(set) var isOffline: Bool = false
    public private(set) var errorMessage: String?
    /// Bumped after every successful pull-to-refresh so the view can fire a
    /// `.sensoryFeedback(.success, trigger:)` haptic. Not part of any AC —
    /// purely UX polish (iOS 17 sensoryFeedback wiring).
    public private(set) var refreshCount: Int = 0
    /// T-765 / CL-162 (DUT-71) — saved recipe ids for the card long-press
    /// Save/Unsave label. Hydrated on every appear; optimistically flipped on
    /// a long-press toggle so the menu is correct on re-open.
    /// DUT — `internal(set)` (was `private(set)`) so the save-toggle helpers
    /// extracted to `FeedViewModel+SaveToggle.swift` (file-length relief) can
    /// flip membership, mirroring `shoppingListSnackbarMessage`'s widening for
    /// the `+ShoppingList` split.
    public internal(set) var savedRecipeIDs: Set<Int> = []
    /// DUT — bumped only on a genuine long-press Save/Unsave so the view can
    /// fire a `.sensoryFeedback(.selection, trigger:)` haptic. Keyed to this
    /// (not `savedRecipeIDs`) so appear/refresh reconciliation of the id set
    /// doesn't mis-fire the haptic (mirrors `CategoryRecipesViewModel`).
    /// `internal(set)` for the same `+SaveToggle` extension-file reason.
    public internal(set) var saveToggleCount: Int = 0

    /// DUT-534 Part 2 — Shopping List snackbar copy + optional trailing action
    /// title ("View"), driven by `FeedViewModel+ShoppingList`, rendered by
    /// `FeedView`. `nil` message hides the snackbar.
    public internal(set) var shoppingListSnackbarMessage: String?
    public internal(set) var shoppingListSnackbarActionTitle: String?

    // DUT-534 Part 2 — internal (was `private`) so `+ShoppingList` reaches it.
    let dependencies: FeedDependencies
    private var currentPage: Int = 0
    private var reachedEnd: Bool = false
    /// DUT-516: O(1) membership set mirroring `items` ids, so `loadMore` can
    /// append only a page's genuinely-new items instead of rebuilding the whole
    /// id list with an O(n²) `reduce`+`contains` and re-projecting every
    /// accumulated row. Kept in lockstep with `items`: reset (via `resetItems`)
    /// wherever `items` is replaced (`loadInitial` commit / cache hydrate) and
    /// extended as `loadMore` appends.
    private var seenIDs = Set<Int>()
    /// DUT-511: monotonic load token (same pattern as `SearchViewModel`'s
    /// `searchGeneration`). `loadInitial` and `loadMore` each bump it at the
    /// start and capture the value locally; after every `await` they re-check
    /// `generation == loadGeneration` before committing `items`/`currentPage`/
    /// `reachedEnd`/`loadState`. A `refresh()` starting a fresh `loadInitial`
    /// supersedes an in-flight `loadMore`, whose post-await guard then fails so
    /// it no-ops instead of clobbering the refreshed list with stale page data.
    /// This is the ordering fix on top of DUT-382's `isLoading` single-flight
    /// (which only gates `loadMoreIfNeeded`, not the unconditional `refresh`).
    private var loadGeneration = 0
    /// Subscription handle for connectivity changes. `@ObservationIgnored`
    /// because no view observes it (a private lifecycle detail) — that also
    /// makes it a real stored property so `nonisolated(unsafe)` applies
    /// meaningfully, letting the nonisolated `deinit` cancel it. `Task` is
    /// `Sendable` and `deinit` fires exactly once, so the access is safe.
    @ObservationIgnored nonisolated(unsafe) private var connectivityTask: Task<Void, Never>?

    /// DUT-541: per-item in-flight guard for card "Add to Shopping List" (see
    /// `addToShoppingList(_:)` in `+ShoppingList`); main-actor-isolated.
    var addingIDs = Set<Int>()

    /// DUT-939 — the id last handed out by `surpriseMe(onSelect:)`, so the
    /// next tap avoids an immediate repeat via `RandomRecipePicker`.
    /// `internal(set)` (was `private(set)`) so the DUT-1062 "Surprise Me"
    /// logic extracted to `FeedViewModel+SurpriseMe.swift` (file-length
    /// relief, mirroring the `+SaveToggle` / `+ShoppingList` splits) can
    /// advance it; still `public` for read so tests can assert it advances.
    public internal(set) var lastSurpriseID: Int?

    /// DUT-1062 — true while a "Surprise Me" tap's full-catalog network
    /// fetch (`dependencies.fetchRandomRecipe()`) is in flight. The view
    /// swaps the dice icon for a spinner while true, mirroring how
    /// `addingIDs` gates the per-card "Add to Shopping List" in-flight
    /// state. `internal(set)` for the same `+SurpriseMe` extension-file
    /// reason as `lastSurpriseID` above.
    public internal(set) var isSurpriseMeLoading = false

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
                // DUT-481: acquire the stream via a weak touch, then re-acquire
                // `self` weakly PER iteration. A `guard let self` before the
                // `for await` upgrades to a strong reference held for the whole
                // loop; the stream never finishes on its own, so that strong ref
                // would pin the view model forever, defeating the `deinit`
                // cancel (VM → Task → self → VM). Per-tick touch lets the strong
                // scope end each iteration so an @State drop deinits.
                guard let stream = await self?.dependencies.connectivityChanges() else { return }
                for await isOnline in stream {
                    await self?.handleConnectivity(isOnline: isOnline)
                }
            }
        }
        if items.isEmpty {
            await loadInitial()
        }
        // Refresh on every appear (not gated on `items.isEmpty`) so a save
        // made on another surface reflects in the card long-press menu.
        await refreshSavedRecipeIDs()
    }

    /// DUT-323 — the celebration the view is presenting; nil otherwise. Set only
    /// via ``promoteCelebrationIfReady()`` once the cookout flow's sheet has
    /// dismissed — never directly from `logCook` (DUT-339). `internal(set)` (was
    /// `private(set)`) so the celebration logic extracted to
    /// `FeedViewModel+Celebration.swift` (file-length relief, mirroring the
    /// `+Journal` / `+SaveToggle` / `+ShoppingList` splits) can set it.
    public internal(set) var celebration: CookCelebration?

    /// DUT-339 — a celebration earned by a just-logged cook, held until the
    /// cookout flow's sheet has actually dismissed. Presenting a `.sheet` on the
    /// same view that is mid-dismissing another sheet makes iOS silently swallow
    /// it, so the celebration was intermittently lost on device. We promote
    /// pending → `celebration` only when the cookout sheet is gone, triggered by
    /// whichever of {log completes, sheet dismisses} happens last. `internal`
    /// (not `private`) so `+Celebration` can reach it.
    var pendingCelebration: CookCelebration?
    var cookoutSheetVisible = false

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
            !isLoading,
            loadState != .loadingMore,
            loadState != .loadingInitial,
            let lastFew = items.suffix(3).first(where: { $0.id == currentItem.id }) ?? items.last,
            lastFew.id == currentItem.id
        else { return }
        await loadMore()
    }

    // MARK: - Private

    /// DUT-516: replace `items` wholesale and rebuild the `seenIDs` membership
    /// set in one step so the two never drift. Used by every path that resets
    /// the feed (`loadInitial` commit, offline-cache hydrate); `loadMore`
    /// appends instead (see below).
    private func resetItems(_ newItems: [RecipeListItem]) {
        items = newItems
        seenIDs = Set(newItems.map(\.id))
    }

    /// DUT-382: single in-flight latch shared by `loadInitial` + `loadMore` so
    /// `loadMoreIfNeeded` can't spawn a concurrent `loadMore` during a
    /// populated-grid pull-to-refresh (which keeps `loadState == .loaded` per
    /// DUT-313 and resets the page cursor below, blinding the `loadState` guards).
    private var isLoading = false

    private func loadInitial(forceReplace: Bool = false) async {
        // DUT-511: supersede any in-flight load (notably a `loadMore` running
        // when a `refresh` starts). Bumped before the first `await` so a
        // suspended `loadMore` resuming after us fails its own post-await guard.
        loadGeneration &+= 1
        let generation = loadGeneration
        isLoading = true
        defer { isLoading = false }
        // DUT-313: a pull-to-refresh on a populated grid must NOT blank the
        // feed into full-screen skeletons. `.loadingInitial` renders skeletons
        // (FeedView.content), so only enter it when there is nothing to show —
        // a true first load. On the refresh/forceReplace path with items
        // already loaded, keep `.loaded` (the system .refreshable spinner
        // overlays the list) and swap content in only when the fresh page
        // arrives, mirroring loadMore's non-destructive pattern.
        if !(forceReplace && !items.isEmpty) {
            loadState = .loadingInitial
        }
        errorMessage = nil
        currentPage = 0
        reachedEnd = false
        do {
            // A blocklist can filter a fetched page down to zero VISIBLE items
            // even though the raw page wasn't empty and more pages remain — see
            // `fetchFirstVisiblePage`. `nil` means a newer load superseded us.
            guard let firstVisible = try await fetchFirstVisiblePage(generation: generation) else {
                return
            }
            resetItems(firstVisible.items)
            currentPage = firstVisible.page
            reachedEnd = firstVisible.reachedEnd
            loadState = items.isEmpty ? .empty : .loaded
            // Hand the freshly-loaded top-of-feed to the home-screen widget
            // (spec.md US-9, AC-9.3). Fire-and-forget; failures inside the
            // dependency are logged there, never thrown.
            await dependencies.publishWidgetSnapshot(items: items)
        } catch {
            DODLog.network.error("feed initial load failed: \(String(describing: error))")
            // Offline-with-cache (AC-1.6) vs first-launch-offline (AC-1.5):
            // attempt to hydrate from cache. If empty, treat as first launch.
            if !forceReplace, let hydrated = await hydratedFromCache(), !hydrated.isEmpty {
                // DUT-511: bail if a newer load superseded this failed one.
                guard generation == loadGeneration else { return }
                resetItems(hydrated)
                isOffline = true
                loadState = .loaded
                return
            }
            // DUT-313: a refresh that fails while the grid is already populated
            // must keep the existing items on screen (mirroring loadMore's
            // non-destructive failure path) rather than blanking into the
            // empty/first-launch-offline state. Surface offline status, but
            // leave items + `.loaded` intact.
            if forceReplace, !items.isEmpty {
                let online = await dependencies.isOnline()
                // DUT-511: bail if a newer load superseded this failed one.
                guard generation == loadGeneration else { return }
                isOffline = !online
                loadState = .loaded
                errorMessage = "Couldn't load recipes."
                return
            }
            let online = await dependencies.isOnline()
            // DUT-511: bail if a newer load superseded this failed one.
            guard generation == loadGeneration else { return }
            isOffline = !online
            // DUT-621: an ONLINE first-launch failure is NOT an empty result —
            // route it to `.firstLaunchFailed` (a failure message + Retry), not
            // the dead-end `.empty` state. `.empty` is reserved for a genuine
            // zero-result success (see the success path above).
            loadState = isOffline ? .firstLaunchOffline : .firstLaunchFailed
            errorMessage = "Couldn't load recipes."
        }
    }

    /// The outcome of paging forward (from page 1) until a page yields visible
    /// items or the real last page is reached.
    private struct FirstVisiblePage {
        var items: [RecipeListItem]
        var page: Int
        var reachedEnd: Bool
    }

    /// Fetch page 1, then keep advancing while the page is filtered down to
    /// zero VISIBLE items (a blocklist wipeout) but more pages remain, so
    /// `loadInitial` never dead-ends into `.empty` while real content sits one
    /// page away — `loadMore` already tolerates the same situation for page 2+
    /// (it just advances the cursor and stays `.loaded`). Returns `nil` when a
    /// newer load (DUT-511) superseded this one mid-fetch; the caller should
    /// drop its writes rather than clobber the fresher list.
    private func fetchFirstVisiblePage(generation: Int) async throws -> FirstVisiblePage? {
        var page = 1
        while true {
            let result = try await dependencies.fetchPosts(page: page)
            try await dependencies.cache(listItems: result.items)
            let fetched = try await dependencies.cachedListItems(forIDs: result.items.map(\.id))
            // DUT-511: a newer load (e.g. a second refresh) superseded us while
            // we awaited — drop our writes rather than clobber the fresh list.
            guard generation == loadGeneration else { return nil }
            // DUT-237: stop at the real last page (X-WP-TotalPages), not at the
            // first page that returns fewer than a full batch.
            let landedOnLastPage = page >= result.totalPages
            if !fetched.isEmpty || landedOnLastPage {
                return FirstVisiblePage(items: fetched, page: page, reachedEnd: landedOnLastPage)
            }
            page += 1
        }
    }

    private func loadMore() async {
        // DUT-511: stamp this load so a `refresh`/`loadInitial` (or another
        // `loadMore`) starting mid-flight supersedes it — the post-await guards
        // below then drop this load's writes instead of clobbering page 1.
        loadGeneration &+= 1
        let generation = loadGeneration
        isLoading = true
        defer { isLoading = false }
        loadState = .loadingMore
        let nextPage = currentPage + 1
        do {
            let page = try await dependencies.fetchPosts(page: nextPage)
            try await dependencies.cache(listItems: page.items)
            // DUT-516: fetch ONLY this page's ids (not the whole accumulated
            // list) and append the not-yet-seen items in page order. The cache
            // read can drop ids (blocklist filtering), so dedupe on the freshly
            // cached page rather than on the raw page ids.
            let fetched = try await dependencies.cachedListItems(forIDs: page.items.map(\.id))
            // DUT-511: a `refresh()` (or newer load) superseded this page while
            // we awaited — drop these stale writes rather than clobber the fresh
            // list / rewind `currentPage` to the stale page-2 cursor. Re-checked
            // AFTER the awaits and before any mutation of `items`/`seenIDs`.
            guard generation == loadGeneration else { return }
            let newItems = fetched.filter { seenIDs.insert($0.id).inserted }
            items.append(contentsOf: newItems)
            currentPage = nextPage
            // DUT-237: stop at the real last page (X-WP-TotalPages).
            reachedEnd = currentPage >= page.totalPages
            loadState = .loaded
        } catch {
            DODLog.network.error("feed loadMore failed: \(String(describing: error))")
            // DUT-511: a superseded failed load must not touch `loadState` — the
            // newer load owns it now.
            guard generation == loadGeneration else { return }
            // DUT-237 / DUT-223: a transient tail-pagination failure must NOT
            // latch `reachedEnd` — that permanently kills infinite scroll for
            // the session. Keep what we have; a later near-bottom appearance
            // retries the same page.
            loadState = .loaded
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

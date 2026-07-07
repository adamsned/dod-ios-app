import DODDomain
import DODNetworking
import DODSupport
import Foundation
import Observation

/// Recipes in a single category, paged.
/// Spec trace: AC-2.3, AC-2.5.
@Observable
@MainActor
public final class CategoryRecipesViewModel {

    public enum LoadState: Equatable {
        // DUT-695 — `.offline` splits a connectivity failure out of the generic
        // `.error` so an offline user on the initial load gets a "reconnect"
        // hint (mirroring Search / Feed) instead of the generic "Couldn't load".
        case idle, loadingInitial, loaded, loadingMore, empty, error, offline
    }

    public let category: DODDomain.Category
    public private(set) var items: [RecipeListItem] = []
    public private(set) var loadState: LoadState = .idle
    /// T-765 / CL-162 (DUT-71) — saved recipe ids for the card long-press
    /// Save/Unsave label (hydrated on appear; optimistic flip on toggle).
    public private(set) var savedRecipeIDs: Set<Int> = []
    /// DUT-693 (PR6) — bumped after every clean reload (pull-to-refresh or a
    /// successful retry) so the view can fire a `.sensoryFeedback(.success,
    /// trigger:)` haptic. Not part of any AC — UX polish mirroring
    /// `FeedViewModel.refreshCount`.
    public private(set) var refreshCount: Int = 0
    /// DUT-697 — bumped only on a genuine long-press Save/Unsave so the view can
    /// fire a `.sensoryFeedback(.selection, trigger:)` haptic. Keyed to this
    /// (not `savedRecipeIDs`) so appear/refresh reconciliation of the id set
    /// doesn't mis-fire the haptic.
    public private(set) var saveToggleCount: Int = 0

    private let dependencies: CategoriesDependencies
    private var currentPage: Int = 0
    private var reachedEnd: Bool = false

    public init(category: DODDomain.Category, dependencies: CategoriesDependencies) {
        self.category = category
        self.dependencies = dependencies
    }

    public func onAppear() async {
        // Refresh first (ungated) so a save made on another surface reflects
        // in the card long-press menu even when items are already loaded.
        await refreshSavedRecipeIDs()
        guard items.isEmpty else { return }
        await load(page: 1)
    }

    /// T-765 / CL-162 (DUT-71) — reload the saved-id set from the store (cheap
    /// id projection); called on every appear so a save made on another surface
    /// reflects in the card long-press menu's Save/Unsave label.
    public func refreshSavedRecipeIDs() async {
        if let ids = try? await dependencies.savedRecipeIDs() {
            savedRecipeIDs = ids
        }
    }

    /// Optimistically flip a recipe's saved membership on a long-press toggle
    /// so the menu label is correct on re-open; the next refresh reconciles.
    public func applyOptimisticSaveToggle(id: Int) {
        if savedRecipeIDs.contains(id) {
            savedRecipeIDs.remove(id)
        } else {
            savedRecipeIDs.insert(id)
        }
        // DUT-697 — signal the view to fire the `.selection` haptic on this
        // genuine user toggle only (not on appear/refresh set reconciliation).
        saveToggleCount &+= 1
    }

    public func retry() async {
        // DUT-693 (PR6) — a successful retry earns a `.success` haptic; a failed
        // reload leaves `refreshCount` untouched (no reward on failure),
        // mirroring `FeedViewModel.refresh`.
        if await load(page: 1) {
            refreshCount &+= 1
        }
    }

    /// DUT-693 (PR6) — pull-to-refresh. Resets to page 1 and reloads the
    /// category's recipes, mirroring Feed / Saved. Load-more pagination
    /// (`currentPage` / `reachedEnd`) is reset by the page-1 `load` below, so
    /// the DUT-265 / DUT-282 paging contract is preserved. When the grid is
    /// already populated we keep it on screen (the system refresh spinner
    /// covers the reload) instead of blanking to a full-screen ProgressView —
    /// mirrors `FeedViewModel.refresh` / DUT-313.
    public func refresh() async {
        await refreshSavedRecipeIDs()
        // A failed refresh keeps the populated grid on `.loaded`, so gate the
        // `.success` haptic on the reload actually succeeding — not on the
        // (deliberately preserved) load state.
        if await load(page: 1, keepStateWhilePopulated: true) {
            refreshCount &+= 1
        }
    }

    public func loadMoreIfNeeded(currentItem: RecipeListItem) async {
        guard !reachedEnd,
            loadState == .loaded,
            items.suffix(3).contains(where: { $0.id == currentItem.id })
        else { return }
        await load(page: currentPage + 1, append: true)
    }

    /// Loads a page of the category's recipes. Returns `true` on a clean fetch
    /// so `retry` / `refresh` can gate their `.success` haptic on real success
    /// (a failed refresh deliberately keeps the grid on `.loaded`, so the load
    /// state alone can't distinguish success from a preserved-grid failure).
    @discardableResult
    private func load(page: Int, append: Bool = false, keepStateWhilePopulated: Bool = false) async -> Bool {
        if append {
            loadState = .loadingMore
        } else if keepStateWhilePopulated, !items.isEmpty {
            // DUT-693 (PR6) — pull-to-refresh on a populated grid: keep the
            // current `.loaded` state so the list stays visible under the
            // system refresh spinner instead of flashing a full-screen
            // ProgressView (mirrors the Feed's DUT-313 refresh behaviour).
        } else {
            loadState = .loadingInitial
        }
        do {
            let result = try await dependencies.fetchPosts(categoryID: category.id, page: page)
            try await dependencies.cache(listItems: result.items)
            if append {
                // DUT-425: merge the fetched page in-memory rather than re-reading
                // through the LRU cache — page-1 items (older lastViewedAt) can be
                // evicted by the time page 2 is cached, and cachedListItems(forIDs:)
                // silently drops missing ids, vanishing already-shown recipes.
                var seen = Set(items.map(\.id))
                items += result.items.filter { seen.insert($0.id).inserted }
            } else {
                items = try await dependencies.cachedListItems(forIDs: result.items.map(\.id))
            }
            currentPage = page
            // DUT-265: stop at the real last page (X-WP-TotalPages), not at a
            // short page — mirrors the DUT-237 feed fix.
            reachedEnd = currentPage >= result.totalPages
            loadState = items.isEmpty ? .empty : .loaded
            return true
        } catch {
            DODLog.network.error("category load failed: \(String(describing: error))")
            // DUT-282: a transient APPEND (loadMore) failure must not wipe the
            // already-loaded grid to a full-screen error + reset pagination —
            // keep the items + the `.loaded` state so a later near-bottom
            // appearance retries (mirrors FeedViewModel.loadMore / DUT-223).
            // Only a failed INITIAL load shows the error screen. A failed
            // pull-to-refresh on a populated grid (DUT-693) likewise keeps the
            // existing items + `.loaded` rather than wiping to the error screen.
            if append || keepStateWhilePopulated, !items.isEmpty {
                loadState = .loaded
            } else {
                // DUT-695 — a failed INITIAL load: distinguish a connectivity
                // failure (offline / lost connection / timeout) from a generic
                // error so the view can show a "reconnect" hint with Retry
                // instead of the generic "Couldn't load". Reuses the shared
                // `WPClientError.wrap` classifier (same mapping Search / Feed use).
                loadState = isOfflineError(error) ? .offline : .error
            }
            return false
        }
    }

    /// DUT-695 — classify a thrown load error as a connectivity failure. Uses
    /// the shared `WPClientError.wrap` (the same URLError mapping Search / Feed
    /// rely on) so "offline" here means the exact set the networking layer
    /// treats as no-connectivity: no connection, a dropped connection, or a
    /// timeout.
    private func isOfflineError(_ error: Error) -> Bool {
        switch WPClientError.wrap(error) {
        case .networkUnavailable, .timeout:
            return true
        default:
            return false
        }
    }
}

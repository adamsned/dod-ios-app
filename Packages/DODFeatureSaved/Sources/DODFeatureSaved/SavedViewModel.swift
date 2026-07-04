import DODDomain
import DODSupport
import Foundation
import Observation

/// Spec trace: AC-5.3 (saved list), AC-5.8 (empty state), DUT-6 (refresh on
/// CloudKit remote import).
@Observable
@MainActor
public final class SavedViewModel {

    public enum LoadState: Equatable {
        case idle, loading, loaded, empty, error
    }

    public private(set) var recipes: [Recipe] = []
    /// T-774 / DUT-80 — ids of recipes explicitly downloaded for offline use,
    /// hydrated alongside `recipes` in ``refresh()``. ``SavedView`` checks
    /// membership to render the "Downloaded" badge on saved + downloaded cards.
    public private(set) var downloadedIDs: Set<Int> = []
    public private(set) var loadState: LoadState = .idle

    private let dependencies: SavedDependencies

    /// Subscription handle for CloudKit remote-import signals (DUT-6).
    /// `@ObservationIgnored` because no view observes it (a private lifecycle
    /// detail) — that also makes it a real stored property so
    /// `nonisolated(unsafe)` applies meaningfully, letting the nonisolated
    /// `deinit` cancel it. `Task` is `Sendable` and `deinit` fires exactly
    /// once, so the access is safe. Mirrors `FeedViewModel.connectivityTask`.
    @ObservationIgnored nonisolated(unsafe) private var remoteChangeTask: Task<Void, Never>?

    /// In-flight debounce task. A burst of remote-change signals (CloudKit
    /// often imports several record zones back-to-back) cancels and restarts
    /// this, so the expensive ``refresh()`` runs once after the burst settles
    /// rather than once per signal.
    @ObservationIgnored private var debounceTask: Task<Void, Never>?

    /// How long to wait after the last remote-change signal before
    /// re-fetching. Long enough to coalesce a multi-zone import burst, short
    /// enough that a synced recipe appears effectively immediately.
    static let remoteChangeDebounce: Duration = .milliseconds(300)

    /// One optimistic-unsave suppression: WHEN the user tapped Unsave, on both
    /// clocks. ``markedAt`` (monotonic) drives the DUT-482 TTL; ``markedDate``
    /// (wall clock) is compared against the store's synced `savedAt` in
    /// ``refresh()`` to spot a re-save (DUT-513) — the store timestamps are
    /// `Date`s, so the comparison needs a wall-clock marker.
    struct PendingRemoval {
        let markedAt: ContinuousClock.Instant
        let markedDate: Date
    }

    /// DUT-370: ids optimistically removed by an Unsave tap whose store write
    /// hasn't committed yet, each stamped with WHEN it was marked. `refresh()`
    /// suppresses these from the fetched set until the store stops returning
    /// them (write confirmed) so a debounced remote-change refresh can't briefly
    /// resurrect a just-unsaved card then drop it again.
    ///
    /// DUT-482: the stamp bounds the suppression to ``pendingRemovalTTL``. The
    /// old set-based version cleared an id ONLY when the store stopped returning
    /// it — so unsaving then RE-saving a recipe (from Search/Feed/detail) left
    /// it in the fetch set, kept it suppressed, and hid it from the Saved tab
    /// for the rest of the session. Past the TTL a still-returned id is treated
    /// as a genuine re-save and shown again.
    ///
    /// DUT-513: within the TTL, a re-save is now caught the instant it happens —
    /// `refresh()` drops the entry as soon as the store reports the id with a
    /// `savedAt` newer than ``PendingRemoval/markedDate`` — instead of waiting
    /// the full TTL out.
    @ObservationIgnored private var pendingRemovals: [Int: PendingRemoval] = [:]

    /// DUT-482: how long an optimistic unsave stays suppressed before a
    /// still-present id is read as a re-save. Comfortably exceeds the store
    /// write-commit window (and ``remoteChangeDebounce``); `var` so tests can
    /// shrink it.
    @ObservationIgnored var pendingRemovalTTL: Duration = .seconds(2)

    public init(dependencies: SavedDependencies) {
        self.dependencies = dependencies
    }

    deinit {
        remoteChangeTask?.cancel()
    }

    /// Re-runs every time the view appears so changes from the detail screen
    /// surface immediately.
    public func refresh() async {
        // DUT-369: never blank a populated grid to a full-screen spinner on a
        // background remote-change refresh — only show the loading state on the
        // true first load (mirrors FeedViewModel's DUT-313 fix).
        if recipes.isEmpty { loadState = .loading }
        do {
            let fetchedWithSavedAt = try await dependencies.savedRecipesWithSavedAt()
            // Newest synced `savedAt` per id, for the DUT-513 re-save check below.
            var savedAtByID: [Int: Date] = [:]
            for entry in fetchedWithSavedAt {
                savedAtByID[entry.recipe.id] = max(
                    savedAtByID[entry.recipe.id] ?? .distantPast,
                    entry.savedAt
                )
            }
            var fetched = fetchedWithSavedAt.map(\.recipe)
            // Keep suppressing only ids whose unsave is genuinely still in flight.
            // Drop an entry when ANY of:
            //   • the store no longer returns the id — the unsave write committed;
            //   • DUT-482: the TTL elapsed while the id is still returned;
            //   • DUT-513: the id is returned with a `savedAt` NEWER than when the
            //     user tapped Unsave — a real re-save (from any surface that
            //     writes a fresh `SyncedSavedRecipe`), so show it again at once
            //     rather than holding it hidden for the rest of the TTL.
            // Otherwise (returned, within TTL, save time predates the unsave) it
            // is the DUT-370 not-yet-committed write and stays suppressed.
            let now = ContinuousClock.now
            pendingRemovals = pendingRemovals.filter { id, pending in
                guard let savedAt = savedAtByID[id] else { return false }
                guard now - pending.markedAt < pendingRemovalTTL else { return false }
                return savedAt <= pending.markedDate
            }
            fetched.removeAll { pendingRemovals.keys.contains($0.id) }
            recipes = fetched
            // Best-effort: a download-state read failure just means no badges,
            // never a failed Saved-tab load (T-774 / DUT-80).
            downloadedIDs = (try? await dependencies.downloadedRecipeIDs()) ?? []
            loadState = recipes.isEmpty ? .empty : .loaded
            // DUT-365: republish the home-screen widget so a cross-device
            // save/unsave (which reaches us via the remote-change refresh) updates
            // it — nothing else republishes on the CloudKit-import path.
            await dependencies.publishSavedWidget()
        } catch {
            DODLog.persistence.error("saved load failed: \(String(describing: error))")
            // DUT-369: keep the existing grid on a refresh failure; only surface
            // the error state when there's nothing already on screen.
            if recipes.isEmpty { loadState = .error }
        }
    }

    /// DUT-487 — hydrate a recipe's ingredients before it feeds the Shopping
    /// List, delegating to ``SavedDependencies/recipeWithIngredients(_:)``.
    /// ``SavedView`` passes this to the pushed ``ShoppingListView`` so its
    /// recipe picker fills each selected (possibly never-opened, empty-
    /// ingredients) recipe before building rows. Exposed here because
    /// `dependencies` is private to the view model.
    public func recipeWithIngredients(_ recipe: Recipe) async -> Recipe {
        await dependencies.recipeWithIngredients(recipe)
    }

    /// Begin observing CloudKit remote-import signals so a recipe saved on
    /// another device appears on this one without a relaunch (DUT-6, the
    /// UI-refresh half). Idempotent — a second call while already subscribed
    /// is a no-op, so the view's `.task` can call it on every appear. The
    /// subscription lives for the view model's lifetime (cancelled in
    /// `deinit`); the `.task`-driven appear already covers the foreground
    /// refresh, and signals that arrive while the tab is backgrounded simply
    /// reconcile on the next debounced re-fetch. Mirrors
    /// `FeedViewModel.onAppear`'s connectivity subscription.
    public func startObserving() {
        guard remoteChangeTask == nil else { return }
        remoteChangeTask = Task { [weak self] in
            // DUT-481: read the stream via a weak touch, then re-acquire `self`
            // weakly PER iteration. A `guard let self` before the `for await`
            // would upgrade to a strong reference held for the whole loop — and
            // the stream never ends on its own, so the strong ref would keep the
            // view model alive forever, defeating the `deinit`-driven cancel
            // (the cycle VM → Task → self → VM). Touching `self` per tick lets
            // the strong scope end each iteration, so an @State drop deinits.
            guard let stream = self?.dependencies.remoteChanges() else { return }
            for await _ in stream {
                guard let self else { return }
                self.remoteChangeDidArrive()
            }
        }
    }

    /// Coalesce a remote-change signal into a single debounced ``refresh()``.
    /// Each signal cancels the pending debounce and restarts the timer, so a
    /// rapid import burst collapses to one re-fetch once it settles.
    private func remoteChangeDidArrive() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: Self.remoteChangeDebounce)
            guard !Task.isCancelled else { return }
            await self?.refresh()
        }
    }

    /// Optimistically remove a recipe from the displayed list the instant the
    /// user taps Unsave from the context menu — the store toggle bubbles
    /// through TabStack asynchronously (no completion callback), so without
    /// this the card lingers until the next `.task` cycle (tab switch).
    /// `refresh()` reconciles on next appear if the store write somehow
    /// failed. T-635 / CL-104.
    public func optimisticallyRemove(id: Int) {
        // DUT-370/482: suppress until commit, bounded by the TTL. DUT-513: stamp
        // the wall-clock time too so `refresh()` can compare it against the
        // store's synced `savedAt` and lift the suppression the moment a re-save
        // lands.
        pendingRemovals[id] = PendingRemoval(markedAt: .now, markedDate: .now)
        recipes.removeAll { $0.id == id }
        loadState = recipes.isEmpty ? .empty : .loaded
    }

    /// DUT-513 — manually drop a recipe's optimistic-unsave suppression. The
    /// production re-save path no longer relies on this: ``refresh()`` clears
    /// the suppression automatically the moment the store reports the id with a
    /// `savedAt` newer than the unsave (see ``savedRecipesWithSavedAt()``), so a
    /// re-save from ANY surface (Feed/Search/Category/detail) surfaces the card
    /// without an explicit clear call — the previous PR-#392 attempt wired this
    /// only into tests and left the bug live. Kept as an idempotent escape hatch
    /// (safe for ids that were never pending); it does not bypass the DUT-482 TTL
    /// for a genuine in-flight unsave, which the store-timestamp check governs.
    public func clearPendingRemoval(id: Int) {
        pendingRemovals[id] = nil
    }

    /// T-775 / DUT-81 — un-download from the Saved-tab context menu. Clears the
    /// "Downloaded" badge optimistically (mirrors ``optimisticallyRemove(id:)``)
    /// so the capsule disappears instantly, then routes the store write through
    /// the dependency. The recipe stays saved, so the card remains in the grid;
    /// a failed write reconciles on the next ``refresh()``.
    public func removeDownload(id: Int) async {
        downloadedIDs.remove(id)
        do {
            try await dependencies.removeDownload(id: id)
        } catch {
            DODLog.persistence.error("remove download failed: \(String(describing: error))")
        }
    }

    /// DUT-229 — the Saved-tab "Remove Download" entry point. Removal is instant
    /// whether online OR offline: `removeDownload` only clears the `downloadedAt`
    /// pin (the recipe stays saved, its text and pinned hero image survive), so
    /// the recipe still opens offline afterward. Nothing is stranded, so the old
    /// DUT-84 offline confirmation guarded a non-existent risk and is gone.
    public func requestRemoveDownload(id: Int) async {
        await removeDownload(id: id)
    }
}

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

    public init(dependencies: SavedDependencies) {
        self.dependencies = dependencies
    }

    deinit {
        remoteChangeTask?.cancel()
    }

    /// Re-runs every time the view appears so changes from the detail screen
    /// surface immediately.
    public func refresh() async {
        loadState = .loading
        do {
            recipes = try await dependencies.savedRecipes()
            // Best-effort: a download-state read failure just means no badges,
            // never a failed Saved-tab load (T-774 / DUT-80).
            downloadedIDs = (try? await dependencies.downloadedRecipeIDs()) ?? []
            loadState = recipes.isEmpty ? .empty : .loaded
        } catch {
            DODLog.persistence.error("saved load failed: \(String(describing: error))")
            loadState = .error
        }
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
            guard let self else { return }
            let stream = dependencies.remoteChanges()
            for await _ in stream {
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
        recipes.removeAll { $0.id == id }
        loadState = recipes.isEmpty ? .empty : .loaded
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
}

import DODDomain
import DODNetworking
import DODPersistence
import Foundation

public protocol SavedDependencies: Sendable {
    func savedRecipes() async throws -> [Recipe]
    /// T-774 / DUT-80 — the id set of recipes explicitly downloaded for offline
    /// use (`CachedRecipe.downloadedAt != nil`), so the Saved tab can render a
    /// "Downloaded" badge on the saved cards that are also downloaded. Default
    /// `[]` (no badges) so existing fake conformers keep compiling; the live
    /// wiring routes to ``RecipeStore/downloadedRecipeIDs()``.
    func downloadedRecipeIDs() async throws -> Set<Int>
    /// Pre-download hero images for newly-saved recipe (AC-5.2).
    func preDownloadImages(forRecipeID: Int, urls: [URL]) async
    /// Emit a signal every time the on-disk store changes underneath us
    /// because CloudKit imported remote changes from another device (DUT-6,
    /// the UI-refresh half). The Saved tab reads through a one-shot
    /// `@ModelActor` fetch (``savedRecipes()``), so without an external nudge
    /// a remote import silently updates the store while the displayed list
    /// keeps its stale snapshot until the next appear/relaunch. The view
    /// model subscribes to this stream while the tab is visible and
    /// re-runs ``savedRecipes()`` (debounced) on each signal.
    ///
    /// Mirrors ``FeedDependencies/connectivityChanges()`` — an `AsyncStream`
    /// seam the live App-target wiring feeds (from `NotificationCenter`'s
    /// CloudKit mirror events) and unit tests drive with a synthetic
    /// continuation. The default implementation returns an immediately
    /// finished stream so existing fake conformers keep compiling and a
    /// build with no CloudKit container simply never refreshes out-of-band.
    func remoteChanges() -> AsyncStream<Void>
}

extension SavedDependencies {
    public func remoteChanges() -> AsyncStream<Void> {
        AsyncStream { $0.finish() }
    }

    /// Default: no downloaded recipes, so no "Downloaded" badges. The live
    /// wiring overrides this; fake conformers that don't care about download
    /// state inherit the empty set. T-774 / DUT-80.
    public func downloadedRecipeIDs() async throws -> Set<Int> { [] }
}

public struct LiveSavedDependencies: SavedDependencies {

    /// Sendable hook the app supplies to bridge from this package (which has
    /// no CloudKit / CoreData dependency) over to the CloudKit mirror's
    /// remote-change notifications. The App composition root builds the
    /// stream from `NotificationCenter` — observing
    /// `NSPersistentStoreRemoteChange` and/or
    /// `NSPersistentCloudKitContainer.eventChangedNotification` — and yields
    /// `()` whenever a remote import lands. `nil` (the default) means no live
    /// container is wired, so ``remoteChanges()`` falls back to the protocol
    /// default's finished stream and the Saved tab keeps its appear-only
    /// refresh. DUT-6.
    public typealias RemoteChangeStreamFactory = @Sendable () -> AsyncStream<Void>

    let store: RecipeStore
    let imageLoader: ImageLoader
    private let remoteChangeStream: RemoteChangeStreamFactory?

    public init(
        store: RecipeStore,
        imageLoader: ImageLoader,
        remoteChangeStream: RemoteChangeStreamFactory? = nil
    ) {
        self.store = store
        self.imageLoader = imageLoader
        self.remoteChangeStream = remoteChangeStream
    }

    public func savedRecipes() async throws -> [Recipe] {
        try await store.savedRecipes()
    }

    public func downloadedRecipeIDs() async throws -> Set<Int> {
        try await store.downloadedRecipeIDs()
    }

    public func preDownloadImages(forRecipeID recipeID: Int, urls: [URL]) async {
        for url in urls {
            guard let bytes = try? await imageLoader.data(for: url) else { continue }
            try? await store.cacheImage(url: url, bytes: bytes, pinnedToSavedRecipeID: recipeID)
        }
    }

    public func remoteChanges() -> AsyncStream<Void> {
        guard let remoteChangeStream else {
            return AsyncStream { $0.finish() }
        }
        return remoteChangeStream()
    }
}

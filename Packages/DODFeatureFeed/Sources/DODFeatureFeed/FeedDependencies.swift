import DODDomain
import DODNetworking
import DODPersistence
import DODSupport
import Foundation

/// Narrow surface the Feed feature needs from external modules. Lets us
/// swap real `WPRestClient` for a fake in unit tests without touching the
/// view-model API.
public protocol FeedDependencies: Sendable {
    /// DUT-237: returns the page's items plus WP's total page count
    /// (`X-WP-TotalPages`), so the view model stops paging at the real last
    /// page instead of guessing from a short page.
    func fetchPosts(page: Int) async throws -> (items: [RecipeListItem], totalPages: Int)
    func cache(listItems: [RecipeListItem]) async throws
    func cachedListItems(forIDs ids: [Int]) async throws -> [RecipeListItem]
    func cachedListPage(key: String) async throws -> [Int]?
    func saveListPage(key: String, page: Int, recipeIDs: [Int]) async throws
    func clearBlocklist() async throws
    func isOnline() async -> Bool
    func connectivityChanges() async -> AsyncStream<Bool>
    /// Hand the latest top-of-feed to whoever is publishing snapshots to
    /// the home-screen widget extension (spec.md US-9, AC-9.3). The default
    /// implementation is a no-op so existing fake conformers in unit tests
    /// keep compiling — only the live wiring needs to do anything.
    func publishWidgetSnapshot(items: [RecipeListItem]) async
    /// T-765 / CL-162 (DUT-71) — the id set of saved recipes, used by the
    /// card long-press menu to render the correct Save/Unsave label. Default
    /// `[]` so existing fake conformers keep compiling; the live wiring routes
    /// to ``RecipeStore/savedRecipeIDs()``.
    func savedRecipeIDs() async throws -> Set<Int>
    /// DUT-104 — append a cook to the private journal. Default no-op so existing
    /// test conformers keep compiling; the live wiring routes to
    /// ``RecipeStore/logCook(_:)``.
    func logCook(_ entry: CookLogEntry) async throws
    /// DUT-104 — every logged cook, newest first (for the Cooking Journal view).
    /// Default `[]` so existing test conformers keep compiling.
    func cookLogs() async throws -> [CookLogEntry]
    /// CL-273 — update a journal entry's personal reflection / photo. Default
    /// no-op so existing test conformers keep compiling; the live wiring routes
    /// to ``RecipeStore/updateCookLog(_:)``. Never changes the cook count, so it
    /// can't affect rank.
    func updateCookLog(_ entry: CookLogEntry) async throws
    /// DUT-208 — delete an orphaned cook photo whose journal write failed. The
    /// caller wrote the JPEG to disk before ``logCook(_:)``; when that throws, no
    /// row will ever reference the `photoLocalID`, so the DUT-338 cleanup can't
    /// reach it. Default no-op so existing test conformers keep compiling; the
    /// live wiring routes to ``CookPhotoStore/delete(id:)``.
    func deleteCookPhoto(id: String) async
}

extension FeedDependencies {
    public func publishWidgetSnapshot(items: [RecipeListItem]) async {}
    public func savedRecipeIDs() async throws -> Set<Int> { [] }
    public func logCook(_ entry: CookLogEntry) async throws {}
    public func cookLogs() async throws -> [CookLogEntry] { [] }
    public func updateCookLog(_ entry: CookLogEntry) async throws {}
    public func deleteCookPhoto(id: String) async {}
}

/// Production wiring. Constructed by the app composition root (T-140).
public struct LiveFeedDependencies: FeedDependencies {

    /// Sendable hook the app supplies to bridge from this package
    /// (which has no WidgetKit dependency) over to `WidgetCenter` and any
    /// other widget-aware side effects. Called from a background task
    /// after every successful feed load; receives the same trimmed
    /// entry list that gets persisted to the App Group store.
    public typealias WidgetReloadHook = @Sendable ([WidgetSnapshot.Entry]) -> Void

    /// Sendable hook the app supplies to download hero-image bytes for the
    /// just-snapshotted feed entries and route them through
    /// `RecipeStore.cacheImage(url:bytes:)` so the existing
    /// ``WidgetImageBridge`` writes mirror files into the App Group container.
    /// Fired in a detached `Task` AFTER the snapshot has been written —
    /// feed-load latency is unaffected and per-URL failures inside the
    /// prefetcher are logged + swallowed (the widget renders the gradient
    /// placeholder for the brief window between first feed load and first
    /// timeline tick after prefetch completes). REG-T-360 / CL-45 / T-362.
    public typealias ImagePrefetcher = @Sendable ([URL]) async -> Void

    /// DUT-460 — classifies the latest (top-of-feed) post as an article. The app
    /// supplies this (fetch the post's page + JSON-LD parse; a parse throw means
    /// no Recipe block → article, per CL-63). Returns `true` for an article. The
    /// widget's adaptive eyebrow reads the resulting `Entry.isArticle`. Nil (or a
    /// failed classification) defaults to recipe. Called only for the ONE shown
    /// entry, so it's a single fetch per snapshot publish.
    public typealias LatestKindClassifier = @Sendable (RecipeListItem) async -> Bool

    let client: WPRestClient
    let store: RecipeStore
    let monitor: NetworkMonitor
    private let widgetStore: WidgetSnapshotStore?
    private let widgetReload: WidgetReloadHook?
    private let imagePrefetcher: ImagePrefetcher?
    private let latestKindClassifier: LatestKindClassifier?

    public init(
        client: WPRestClient,
        store: RecipeStore,
        monitor: NetworkMonitor,
        widgetStore: WidgetSnapshotStore? = WidgetSnapshotStore(),
        widgetReload: WidgetReloadHook? = nil,
        imagePrefetcher: ImagePrefetcher? = nil,
        latestKindClassifier: LatestKindClassifier? = nil
    ) {
        self.client = client
        self.store = store
        self.monitor = monitor
        self.widgetStore = widgetStore
        self.widgetReload = widgetReload
        self.imagePrefetcher = imagePrefetcher
        self.latestKindClassifier = latestKindClassifier
    }

    public func fetchPosts(page: Int) async throws -> (items: [RecipeListItem], totalPages: Int) {
        try await client.postsPage(page: page)
    }

    public func cache(listItems: [RecipeListItem]) async throws {
        try await store.cache(listItems: listItems)
    }

    public func cachedListItems(forIDs ids: [Int]) async throws -> [RecipeListItem] {
        try await store.listItems(forIDs: ids)
    }

    public func cachedListPage(key: String) async throws -> [Int]? {
        // T-081 reads from CachedListPage; for simplicity in v1 we don't
        // populate it from this feature and return nil. Hydration will come
        // from CachedRecipe directly in T-083.
        nil
    }

    public func saveListPage(key: String, page: Int, recipeIDs: [Int]) async throws {
        // No-op for v1 — see cachedListPage(key:) note above.
    }

    public func clearBlocklist() async throws {
        try await store.clearBlocklist()
    }

    public func isOnline() async -> Bool {
        await monitor.isOnline
    }

    public func connectivityChanges() async -> AsyncStream<Bool> {
        await monitor.changes()
    }

    public func savedRecipeIDs() async throws -> Set<Int> {
        try await store.savedRecipeIDs()
    }

    public func logCook(_ entry: CookLogEntry) async throws {
        try await store.logCook(entry)
    }

    public func cookLogs() async throws -> [CookLogEntry] {
        try await store.allCookLogs()
    }

    public func updateCookLog(_ entry: CookLogEntry) async throws {
        try await store.updateCookLog(entry)
    }

    public func deleteCookPhoto(id: String) async {
        // DUT-208 — mirrors the DUT-423 dedup-branch cleanup in
        // RecipeStore+CookLog: the JPEG was written to disk before the failed
        // `logCook`, so delete it here rather than orphan it.
        CookPhotoStore().delete(id: id)
    }

    public func publishWidgetSnapshot(items: [RecipeListItem]) async {
        // The widget displays one recipe today but the snapshot reserves
        // room for ``WidgetSnapshotConfig.maxEntries`` so we can rotate
        // through them later without changing the wire format. AC-9.3.
        //
        // `heroImageFilename` is populated from the URL via
        // ``WidgetImageBridge.filename(for:)`` for every entry that has
        // a `heroImage`, regardless of whether the bytes are currently
        // on disk. The widget reads the file by name and falls back to
        // the gradient placeholder if absent (AC-21.3). Keeping the
        // snapshot writer itself pure (no I/O) lets the wire-format
        // write stay file-system-free; the parallel hero-image
        // precache below (T-392) handles getting the bytes onto disk
        // through the existing `store.cacheImage` chain which mirrors
        // to the bridge.
        // DUT-460 — classify only the top (shown) post's kind so the widget's
        // eyebrow reads "Latest Article" vs "Latest Recipe". One fetch; defaults
        // to recipe if no classifier is wired or the classification fails.
        var topIsArticle = false
        if let latestKindClassifier, let top = items.first {
            topIsArticle = await latestKindClassifier(top)
        }
        let entries =
            items
            .prefix(WidgetSnapshotConfig.maxEntries)
            .enumerated()
            .map { offset, item in
                WidgetSnapshot.Entry(
                    id: item.id,
                    title: item.title,
                    excerpt: item.excerpt,
                    heroImageURL: item.heroImage,
                    canonicalURL: item.canonicalURL,
                    publishedAt: item.publishedAt,
                    totalTimeDisplay: item.totalTimeDisplay,
                    heroImageFilename: item.heroImage.map(WidgetImageBridge.filename(for:)),
                    isArticle: offset == 0 ? topIsArticle : false
                )
            }
        guard let widgetStore else {
            // App Group missing (e.g. running without the entitlement in a
            // dev simulator). Surface the issue in logs but never throw —
            // the widget gracefully falls back to its placeholder.
            DODLog.app.notice("widget snapshot skipped: App Group store unavailable")
            return
        }
        do {
            try widgetStore.write(entries: Array(entries))
        } catch {
            DODLog.app.error("widget snapshot write failed: \(String(describing: error))")
            return
        }
        widgetReload?(Array(entries))

        // Without this, the widget's deterministic `WidgetImageBridge`
        // filenames point at files that only existed when the user happened
        // to have saved today's featured recipe (REG-T-360 / CL-45). The
        // composition root supplies a prefetcher that routes URLs through
        // `ImageLoader` + `RecipeStore.cacheImage`; detaching keeps feed-load
        // latency unaffected, and per-URL failures are logged + swallowed
        // inside the prefetcher (graceful-fallback contract — AC-21.3).
        guard let imagePrefetcher else { return }
        let urls = entries.compactMap(\.heroImageURL)
        guard !urls.isEmpty else { return }
        Task.detached { [imagePrefetcher, urls] in
            await imagePrefetcher(urls)
        }
    }
}

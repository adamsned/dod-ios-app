import DODDomain
import DODNetworking
import DODPersistence
import DODSupport
import Foundation

/// Narrow surface the Feed feature needs from external modules. Lets us
/// swap real `WPRestClient` for a fake in unit tests without touching the
/// view-model API.
public protocol FeedDependencies: Sendable {
    func fetchPosts(page: Int) async throws -> [RecipeListItem]
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
}

extension FeedDependencies {
    public func publishWidgetSnapshot(items: [RecipeListItem]) async {}
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

    let client: WPRestClient
    let store: RecipeStore
    let monitor: NetworkMonitor
    private let widgetStore: WidgetSnapshotStore?
    private let widgetReload: WidgetReloadHook?
    private let imagePrefetcher: ImagePrefetcher?

    public init(
        client: WPRestClient,
        store: RecipeStore,
        monitor: NetworkMonitor,
        widgetStore: WidgetSnapshotStore? = WidgetSnapshotStore(),
        widgetReload: WidgetReloadHook? = nil,
        imagePrefetcher: ImagePrefetcher? = nil
    ) {
        self.client = client
        self.store = store
        self.monitor = monitor
        self.widgetStore = widgetStore
        self.widgetReload = widgetReload
        self.imagePrefetcher = imagePrefetcher
    }

    public func fetchPosts(page: Int) async throws -> [RecipeListItem] {
        try await client.posts(page: page)
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
        let entries = items.prefix(WidgetSnapshotConfig.maxEntries).map {
            WidgetSnapshot.Entry(
                id: $0.id,
                title: $0.title,
                excerpt: $0.excerpt,
                heroImageURL: $0.heroImage,
                canonicalURL: $0.canonicalURL,
                publishedAt: $0.publishedAt,
                totalTimeDisplay: $0.totalTimeDisplay,
                heroImageFilename: $0.heroImage.map(WidgetImageBridge.filename(for:))
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

        // T-392: Hero-image precache. Without this, `RecipeStore.cacheImage`
        // only ran for *saved* recipes via `SavedDependencies`, so the
        // featured-widget hero file at the bridge path never existed unless
        // the user happened to have saved today's featured recipe — and
        // the widget's `AsyncImage` fell back to the gradient placeholder.
        // We dispatch the fetch on a detached Task so the user-visible feed
        // load doesn't wait on it; failures are logged and swallowed so the
        // graceful-fallback contract (AC-21.3) still holds.
        let heroEntries = Array(entries)
        let store = self.store
        Task.detached { [store, heroEntries] in
            await Self.precacheHeroImages(entries: heroEntries, into: store)
        }
    }

    /// Fetch + cache hero image bytes for every snapshot entry that has a
    /// URL. Calls into the same `store.cacheImage(url:bytes:)` site that
    /// `SavedDependencies` uses on explicit save — `RecipeStore+ImageCache`
    /// mirrors each write to ``WidgetImageBridge`` so the widget extension
    /// can render the bytes without a network fetch. Best-effort by design:
    /// any per-entry failure (network blip, image absent, decode-time error)
    /// is logged and skipped; the widget falls back to the gradient
    /// placeholder for that entry per AC-21.3.
    ///
    /// `nonisolated` + `static` so the detached Task closure can call it
    /// without capturing `self` as a Sendable surface.
    private static func precacheHeroImages(
        entries: [WidgetSnapshot.Entry],
        into store: RecipeStore
    ) async {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 10
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }

        for entry in entries {
            guard let url = entry.heroImageURL else { continue }
            do {
                let (bytes, response) = try await session.data(from: url)
                if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                    DODLog.app.notice(
                        "widget hero precache: HTTP \(http.statusCode, privacy: .public) for \(url.absoluteString, privacy: .public)"
                    )
                    continue
                }
                try await store.cacheImage(url: url, bytes: bytes)
            } catch {
                DODLog.app.notice(
                    "widget hero precache failed for \(url.absoluteString, privacy: .public): \(String(describing: error))"
                )
            }
        }
    }
}

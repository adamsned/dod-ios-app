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
    /// T-775 / DUT-81 — clear a recipe's explicit-download pin (un-download)
    /// so its "Downloaded" badge clears. Default no-op; the live wiring routes
    /// to ``RecipeStore/removeDownload(id:)``. The recipe stays saved.
    func removeDownload(id: Int) async throws
    // DUT-421 — the former `preDownloadImages(forRecipeID:urls:)` (AC-5.2's
    // declared pre-download path) is deleted: it had ZERO production call
    // sites, so the offline-hero guarantee it claimed to own was actually
    // delivered by the widget-publisher prefetch + `cacheImage`'s DUT-292
    // auto-pin (which pins any cached hero whose URL matches a saved recipe's
    // `heroImageURLString`). That pair IS the AC-5.2 mechanism of record —
    // documented here so nobody re-adds a parallel dead path.
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

    /// DUT-84 — is the device online right now? The Saved-tab "Remove Download"
    /// action gates on this: offline, removing a download strands the recipe
    /// (no network to re-fetch it), so the view confirms first; online it
    /// removes immediately. Default `true` so fake conformers that don't model
    /// connectivity read as "online" (no warning); the live wiring reads
    /// ``NetworkMonitor``.
    func isOnline() async -> Bool

    /// DUT-365: republish the saved-recipes home-screen widget snapshot. The view
    /// model calls this after a refresh (incl. the debounced CloudKit remote-import
    /// refresh) so a recipe saved/unsaved on ANOTHER device updates the widget —
    /// nothing else republishes on the import path. Default no-op so fake conformers
    /// (previews/tests) don't need to model the widget.
    func publishSavedWidget() async

    /// DUT-487 — return `recipe` guaranteed to carry its `ingredients`, fetching
    /// the recipe's detail when needed. `RecipeStore.savedRecipes()` returns
    /// `[Recipe]` whose `ingredients` stay EMPTY until the detail has been fetched
    /// (see `RecipeStore+SyncedSaved.swift` — "ingredients/instructions stay
    /// empty… route to detail"), so building the Shopping List straight from the
    /// saved list produced ZERO rows. The Shopping List picker calls this on each
    /// selected recipe before building, so a never-opened saved recipe still
    /// contributes its ingredients.
    ///
    /// Defensive: never throws. A recipe that can't be hydrated (offline, no URL,
    /// parse failure) is returned unchanged and simply contributes no rows — the
    /// same behavior as before this fix. Default is identity so fake conformers
    /// (previews/tests) keep compiling; the live wiring fetches + parses + caches.
    func recipeWithIngredients(_ recipe: Recipe) async -> Recipe
}

extension SavedDependencies {
    public func remoteChanges() -> AsyncStream<Void> {
        AsyncStream { $0.finish() }
    }

    /// Default no-op (see ``publishSavedWidget()``); live wiring republishes the
    /// widget snapshot, fakes inherit the no-op. DUT-365.
    public func publishSavedWidget() async {}

    /// Default: no downloaded recipes, so no "Downloaded" badges. The live
    /// wiring overrides this; fake conformers that don't care about download
    /// state inherit the empty set. T-774 / DUT-80.
    public func downloadedRecipeIDs() async throws -> Set<Int> { [] }

    /// Default no-op so fakes that don't model download state keep compiling
    /// (T-775 / DUT-81). Live routes to ``RecipeStore/removeDownload(id:)``.
    public func removeDownload(id: Int) async throws {}

    /// Default "online" (see ``isOnline()``) so fake conformers opt in only
    /// when a test exercises the offline warning. T-778 / DUT-84.
    public func isOnline() async -> Bool { true }

    /// Default: identity — return the recipe unchanged so fake conformers
    /// (previews/tests) don't need to model the fetch+parse path (DUT-487).
    /// The live wiring (``LiveSavedDependencies``) overrides this to hydrate.
    public func recipeWithIngredients(_ recipe: Recipe) async -> Recipe { recipe }
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
    /// DUT-487 — fetches a recipe page's HTML so ``recipeWithIngredients(_:)``
    /// can hydrate a saved recipe whose `ingredients` are empty (never opened,
    /// so its detail was never parsed). Optional so call sites that don't build
    /// shopping lists can omit it; `nil` skips the network fetch (cache-only).
    private let pageFetcher: RecipePageFetcher?
    private let remoteChangeStream: RemoteChangeStreamFactory?
    /// DUT-84 — process-wide reachability for the offline remove-download
    /// guard. Defaults to ``NetworkMonitor/shared`` (the instance the App
    /// composition root starts), so existing call sites compile unchanged.
    private let monitor: NetworkMonitor
    /// DUT-365 — Sendable hook the app supplies to republish the saved-recipes
    /// widget snapshot. Built in the App target (the only place the widget
    /// publisher is linked); `nil` means no widget republish (previews/tests).
    public typealias WidgetPublishHook = @Sendable () async -> Void
    private let publishWidget: WidgetPublishHook?

    public init(
        store: RecipeStore,
        imageLoader: ImageLoader,
        pageFetcher: RecipePageFetcher? = nil,
        remoteChangeStream: RemoteChangeStreamFactory? = nil,
        monitor: NetworkMonitor = .shared,
        publishWidget: WidgetPublishHook? = nil
    ) {
        self.store = store
        self.imageLoader = imageLoader
        self.pageFetcher = pageFetcher
        self.remoteChangeStream = remoteChangeStream
        self.monitor = monitor
        self.publishWidget = publishWidget
    }

    public func publishSavedWidget() async {
        await publishWidget?()
    }

    public func savedRecipes() async throws -> [Recipe] {
        try await store.savedRecipes()
    }

    public func downloadedRecipeIDs() async throws -> Set<Int> {
        try await store.downloadedRecipeIDs()
    }

    public func removeDownload(id: Int) async throws {
        _ = try await store.removeDownload(id: id)
    }

    public func isOnline() async -> Bool {
        await monitor.isOnline
    }

    /// DUT-487 — hydrate a saved recipe's ingredients so the Shopping List can
    /// build rows from it. Mirrors the fetch+parse path
    /// `LiveRecipeDetailDependencies.parseJSONLD` / the widget classifier
    /// (`AppDependencies+WidgetClassifier`) use — same `JSONLDRecipeParser.parse`.
    ///
    /// 1. Already has ingredients → return unchanged (no work).
    /// 2. Store cache (`recipe(id:)`) has ingredients → return the cached copy
    ///    (cheap; hydrated by a prior detail open / merge).
    /// 3. Fetch the page HTML + JSON-LD-parse into a `Recipe` WITH ingredients,
    ///    persist it via `mergeDetail` (so future opens are hydrated), return it.
    /// 4. ANY failure (no fetcher, fetch throws, parse throws) → the ORIGINAL
    ///    recipe unchanged. Defensive — never throws; an un-hydratable recipe
    ///    just contributes no rows, the same as before this fix.
    public func recipeWithIngredients(_ recipe: Recipe) async -> Recipe {
        guard recipe.ingredients.isEmpty else { return recipe }

        // Cheap first: the store cache is hydrated if a detail open merged before.
        if let cached = try? await store.recipe(id: recipe.id), !cached.ingredients.isEmpty {
            return cached
        }

        // Fall back to a fetch + parse. Build a `RecipeListItem` from the recipe
        // to merge the parsed detail onto (the parser stitches list fields —
        // id/title/image — onto the JSON-LD-only detail data, per AC-4.11).
        guard let pageFetcher,
            let html = try? await pageFetcher.html(for: recipe.canonicalURL)
        else {
            return recipe
        }
        let listItem = RecipeListItem(
            id: recipe.id,
            title: recipe.title,
            excerpt: recipe.excerpt,
            heroImage: recipe.heroImage,
            publishedAt: recipe.publishedAt,
            canonicalURL: recipe.canonicalURL,
            categoryIDs: recipe.categoryIDs
        )
        guard
            let hydrated = try? JSONLDRecipeParser.parse(
                html: html,
                merging: listItem,
                canonicalURL: recipe.canonicalURL
            )
        else {
            return recipe
        }
        // Persist so future opens are hydrated (best-effort — a merge failure
        // just means we re-fetch next time; the rows still build from `hydrated`).
        try? await store.mergeDetail(hydrated)
        return hydrated
    }

    // DUT-421 — `preDownloadImages` deleted; see the protocol-site note.

    public func remoteChanges() -> AsyncStream<Void> {
        guard let remoteChangeStream else {
            return AsyncStream { $0.finish() }
        }
        return remoteChangeStream()
    }
}

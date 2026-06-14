import DODPersistence
import DODSupport
import Foundation

/// Bridges between the `RecipeStore` saved-set and the saved-recipes
/// home-screen widget snapshot (spec.md US-17 / AC-17.3 + AC-17.6 host
/// side). Built by `LiveRecipeDetailDependencies` and run after every
/// `toggleSaved(...)` so the widget timeline refreshes the instant the
/// user adds or removes a save.
///
/// Mirrors the existing featured-widget pattern at
/// `LiveFeedDependencies.publishWidgetSnapshot(items:)`: read from the
/// store, build the small payload, write via `WidgetSnapshotStore`, then
/// invoke an optional reload hook that the host app supplies (the package
/// itself never imports WidgetKit). The reload hook is what calls
/// `WidgetCenter.shared.reloadTimelines(ofKind: "SavedRecipesWidget")` —
/// see `App/AppDependencies.swift` for the call site.
///
/// Spec trace: T-322 (P8-widget-host), CL-28 (refresh trigger).
public struct SavedRecipesWidgetPublisher: Sendable {

    /// Same shape as `LiveFeedDependencies.WidgetReloadHook`. `Sendable`
    /// because the package itself can't reach WidgetKit — the App target
    /// supplies the closure that does.
    public typealias ReloadHook = @Sendable () -> Void

    /// Sendable hook the app supplies to download hero-image bytes for the
    /// saved recipes and route them through `RecipeStore.cacheImage`, which
    /// mirrors files into the App Group container via ``WidgetImageBridge``
    /// so the widget can render the photo without a widget-side network
    /// fetch (AC-17.6). Mirrors `LiveFeedDependencies.ImagePrefetcher`. Fired
    /// detached AFTER the snapshot write, only for saved recipes whose bytes
    /// aren't cached yet (e.g. saved from the feed without ever opening
    /// detail). T-770 / CL-167 (DUT-76).
    public typealias ImagePrefetcher = @Sendable ([URL]) async -> Void

    private let store: RecipeStore
    private let widgetStore: WidgetSnapshotStore?
    private let reload: ReloadHook?
    private let imagePrefetcher: ImagePrefetcher?

    public init(
        store: RecipeStore,
        widgetStore: WidgetSnapshotStore? = WidgetSnapshotStore(),
        reload: ReloadHook? = nil,
        imagePrefetcher: ImagePrefetcher? = nil
    ) {
        self.store = store
        self.widgetStore = widgetStore
        self.reload = reload
        self.imagePrefetcher = imagePrefetcher
    }

    /// Re-read the current saved set, write a fresh snapshot to the App
    /// Group container, and force-reload the saved-recipes widget
    /// timeline. Fire-and-forget at call sites — every failure path inside
    /// this method is logged and swallowed; the widget gracefully falls
    /// back to its placeholder (AC-17.5) if the snapshot is unreadable.
    public func publish() async {
        let rows: [SavedRecipeWidgetRow]
        do {
            rows = try await store.savedRecipesForWidget(
                limit: SavedRecipesWidgetSnapshotConfig.maxEntries
            )
        } catch {
            DODLog.persistence.error(
                "saved-widget publish: store read failed: \(String(describing: error))"
            )
            return
        }

        guard let widgetStore else {
            // App Group missing (e.g. running without the entitlement in a
            // dev simulator). Mirror `LiveFeedDependencies` behavior — log
            // and skip rather than throwing.
            DODLog.app.notice("saved-widget snapshot skipped: App Group store unavailable")
            return
        }

        let entries = rows.map(Self.toSnapshotEntry)

        do {
            if entries.isEmpty {
                // Full clear — write an empty snapshot rather than calling
                // `clearSavedRecipes()` so the widget always sees a fresh
                // `writtenAt` timestamp and rebuilds its timeline. Either
                // path drives the widget to its empty state (AC-17.5).
                try widgetStore.writeSavedRecipes(entries: [])
            } else {
                try widgetStore.writeSavedRecipes(entries: entries)
            }
        } catch {
            DODLog.app.error(
                "saved-widget snapshot write failed: \(String(describing: error))"
            )
            return
        }

        reload?()

        // T-770 / CL-167 (DUT-76) — bridge hero bytes for saved recipes whose
        // photos aren't cached yet (e.g. saved from the feed without ever
        // opening detail, so `RecipeStore.cacheImage` never ran for them).
        // `toSnapshotEntry` now emits the deterministic bridged filename for
        // every row with a hero URL; without this prefetch that filename would
        // point at a file that doesn't exist and `WidgetCard.Hero` would render
        // its gradient fallback. Mirrors the feed's
        // `LiveFeedDependencies.publishWidgetSnapshot` prefetch: detached so the
        // save round-trip isn't blocked on the network, gated on
        // `!heroImageCached` so only the missing photos are fetched, and
        // followed by a second `reload()` so the freshly-bridged photos appear.
        guard let imagePrefetcher else { return }
        let missing = rows.filter { !$0.heroImageCached }.compactMap(\.heroImageURL)
        guard !missing.isEmpty else { return }
        Task.detached { [imagePrefetcher, reload, missing] in
            await imagePrefetcher(missing)
            reload?()
        }
    }

    /// Convert a `SavedRecipeWidgetRow` (DODPersistence projection) into a
    /// `SavedRecipesWidgetSnapshot.Entry` (DODSupport wire format). T-766 /
    /// CL-163 (DUT-72): the hero photo is surfaced via the App Group bridge,
    /// the same path the Featured widget uses — see `heroImageFilename` below.
    static func toSnapshotEntry(_ row: SavedRecipeWidgetRow) -> SavedRecipesWidgetSnapshot.Entry {
        SavedRecipesWidgetSnapshot.Entry(
            recipeID: row.recipeID,
            title: row.title,
            canonicalURL: row.canonicalURL,
            // T-770 / CL-167 (DUT-76) — emit the deterministic bridged filename
            // for every row that has a hero URL, regardless of whether the bytes
            // are cached yet (mirrors `LiveFeedDependencies.publishWidgetSnapshot`).
            // `RecipeStore.cacheImage` mirrors bytes into the App Group container
            // under `WidgetImageBridge.filename(for:)` (AC-21.2); for saves whose
            // bytes aren't cached yet, `publish()`'s detached prefetch fetches +
            // bridges them and reloads. The widget reads the local file (no
            // widget-side network — AC-17.6) and renders the full-color photo, or
            // falls back to `WidgetCard.Hero`'s gradient until the file lands
            // (AC-17.5 / AC-21.3). Supersedes the T-766 / CL-163 `heroImageCached`
            // gate (which left feed-saved recipes permanently photoless).
            heroImageFilename: row.heroImageURL.map(WidgetImageBridge.filename(for:)),
            savedAt: row.savedAt
        )
    }
}

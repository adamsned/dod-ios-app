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

    private let store: RecipeStore
    private let widgetStore: WidgetSnapshotStore?
    private let reload: ReloadHook?

    public init(
        store: RecipeStore,
        widgetStore: WidgetSnapshotStore? = WidgetSnapshotStore(),
        reload: ReloadHook? = nil
    ) {
        self.store = store
        self.widgetStore = widgetStore
        self.reload = reload
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
    }

    /// Convert a `SavedRecipeWidgetRow` (DODPersistence projection) into a
    /// `SavedRecipesWidgetSnapshot.Entry` (DODSupport wire format).
    /// `heroImageFilename` stays `nil` until the host learns to surface
    /// cached image bytes via the App Group container — see the note
    /// below; AC-5.2 stores image bytes in SwiftData (`CachedImage`), not
    /// as files. The widget extension renders a placeholder for `nil`
    /// per AC-17.5, so leaving this nil is the honest representation
    /// today rather than fabricating a filename that doesn't exist.
    static func toSnapshotEntry(_ row: SavedRecipeWidgetRow) -> SavedRecipesWidgetSnapshot.Entry {
        SavedRecipesWidgetSnapshot.Entry(
            recipeID: row.recipeID,
            title: row.title,
            canonicalURL: row.canonicalURL,
            // `heroImageCached` is plumbed through SavedRecipeWidgetRow
            // but we still pass nil here for v1 — even when bytes are
            // present in `CachedImage`, the widget can't read them
            // without a separate App-Group-file bridge that lives outside
            // T-322's scope. Future work: write image files to the App
            // Group container on `preDownloadImages` and use that
            // filename here. T-321 (widget extension) will need to read
            // the file once it exists. For now, the boolean is preserved
            // on the projection type so future commits don't have to
            // re-plumb it.
            heroImageFilename: nil,
            savedAt: row.savedAt
        )
    }
}

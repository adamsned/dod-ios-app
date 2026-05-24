import DODSupport
import Foundation
import WidgetKit

/// Single timeline entry shown by the saved-recipes widget. Wraps the
/// snapshot's entries (capped to the medium-size max of 3) so the same
/// view can render the populated and placeholder states.
///
/// `nil` means the widget renders ``WidgetCard.SavedEmpty`` (US-17 CL-27).
struct SavedRecipesEntry: TimelineEntry {

    /// Schedule slot WidgetKit hands to the view.
    let date: Date

    /// Up to ``SavedRecipesWidgetSnapshotConfig/maxEntries`` (3) saved
    /// recipes, sorted most-recently-saved first. Empty array means
    /// "render the empty-state placeholder" (AC-17.5).
    let entries: [SavedRecipesWidgetSnapshot.Entry]

    /// WidgetKit gallery / redacted-preview entry. Three sample rows so
    /// the medium-size preview looks populated; small picks the first.
    static let placeholder = SavedRecipesEntry(
        date: Date(timeIntervalSince1970: 1_700_000_000),
        entries: [
            .init(
                recipeID: 1,
                title: "Garlic Butter Skillet Corn",
                canonicalURL: URL(fileURLWithPath: "/"),
                heroImageFilename: nil,
                savedAt: Date(timeIntervalSince1970: 1_700_000_300)
            ),
            .init(
                recipeID: 2,
                title: "Sourdough Bread",
                canonicalURL: URL(fileURLWithPath: "/"),
                heroImageFilename: nil,
                savedAt: Date(timeIntervalSince1970: 1_700_000_200)
            ),
            .init(
                recipeID: 3,
                title: "Cast Iron Pizza",
                canonicalURL: URL(fileURLWithPath: "/"),
                heroImageFilename: nil,
                savedAt: Date(timeIntervalSince1970: 1_700_000_100)
            ),
        ]
    )
}

/// Reads the App-Group saved-recipes snapshot the main app writes and
/// produces a timeline. Mirrors ``FeaturedRecipeTimelineProvider`` —
/// same 4-hour fallback refresh, same `reloadTimelines(ofKind:)` preempt
/// from the host app on every saved-set mutation (T-322 / AC-17.6).
struct SavedRecipesTimelineProvider: TimelineProvider {

    /// Lazily-built reader. Initializer can fail if the App Group isn't
    /// provisioned (e.g. running the widget in a vanilla simulator slice
    /// without the entitlement) — in that case `read()` calls return nil
    /// and we surface the empty-state placeholder, which is the
    /// gracefully-degraded outcome AC-17.5 expects.
    private var store: WidgetSnapshotStore? {
        WidgetSnapshotStore()
    }

    /// How far ahead we schedule the next forced refresh in the absence
    /// of an explicit `reloadTimelines(ofKind:)` from the app. Matches
    /// the featured widget's cadence so both kinds refresh in lockstep.
    private let refreshInterval: TimeInterval = 4 * 60 * 60

    func placeholder(in context: Context) -> SavedRecipesEntry {
        SavedRecipesEntry.placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (SavedRecipesEntry) -> Void) {
        // In the widget gallery (`context.isPreview`) WidgetKit wants a
        // representative non-blank entry. Use the placeholder rather than
        // hitting the App Group so the gallery render is fast and offline.
        if context.isPreview {
            completion(.placeholder)
            return
        }
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SavedRecipesEntry>) -> Void) {
        let entry = currentEntry()
        let next = Date().addingTimeInterval(refreshInterval)
        let timeline = Timeline(entries: [entry], policy: .after(next))
        completion(timeline)
    }

    // MARK: - Private

    private func currentEntry() -> SavedRecipesEntry {
        let snapshot = store?.readSavedRecipes()
        let entries = snapshot?.entries ?? []
        return SavedRecipesEntry(date: Date(), entries: entries)
    }
}

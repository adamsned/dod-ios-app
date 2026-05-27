import DODSupport
import Foundation
import WidgetKit

/// Single timeline entry shown by the featured-recipe widget. Wraps a
/// ``WidgetSnapshot/Entry?`` so the same view can render the populated and
/// placeholder states.
struct FeaturedRecipeEntry: TimelineEntry {

    /// Schedule slot WidgetKit hands to the view.
    let date: Date

    /// `nil` means show the placeholder (first launch, or the snapshot file
    /// is empty / version-mismatched). AC-9.4.
    let recipe: WidgetSnapshot.Entry?

    /// Placeholder shown by WidgetKit before any data is available — e.g.
    /// in the widget gallery, redacted screenshots, or while the user is
    /// still picking a size.
    static let placeholder = FeaturedRecipeEntry(
        date: Date(timeIntervalSince1970: 1_700_000_000),
        recipe: .init(
            id: 0,
            title: "Garlic Butter Skillet Corn",
            excerpt: "An easy 15-minute side dish that pairs with everything.",
            heroImageURL: nil,
            canonicalURL: nil,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            totalTimeDisplay: "15 min"
        )
    )
}

/// Reads the App-Group snapshot the main app writes and produces a timeline.
///
/// Strategy: read the latest snapshot now, render it for the next 4 hours,
/// then ask WidgetKit to refresh. The app also calls
/// `WidgetCenter.shared.reloadAllTimelines()` whenever it writes a new
/// snapshot, which preempts our 4-hour cadence (AC-9.3).
struct FeaturedRecipeTimelineProvider: TimelineProvider {

    /// Lazily-built reader. Initializer can fail if the App Group isn't
    /// provisioned (e.g. running the widget in a vanilla simulator slice
    /// without the entitlement) — in that case `read()` calls return nil
    /// and we surface the placeholder, which is the gracefully-degraded
    /// outcome AC-9.4 expects.
    private var store: WidgetSnapshotStore? {
        WidgetSnapshotStore()
    }

    /// How far ahead we schedule the next forced refresh in the absence of
    /// an explicit `reloadAllTimelines()` from the app.
    private let refreshInterval: TimeInterval = 4 * 60 * 60

    func placeholder(in context: Context) -> FeaturedRecipeEntry {
        FeaturedRecipeEntry.placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (FeaturedRecipeEntry) -> Void) {
        // In the widget gallery (`context.isPreview`) WidgetKit wants a
        // representative non-blank entry. Prefer the live snapshot so the
        // gallery shows the current recipe + real hero image — the moment
        // the user is deciding whether to add the widget is the most
        // important impression in the widget's lifecycle. Fall back to
        // the hardcoded brand placeholder only when the App Group is
        // empty (first launch before the feed has loaded). T-391.
        if context.isPreview {
            let entry = currentEntry()
            completion(entry.recipe == nil ? .placeholder : entry)
            return
        }
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FeaturedRecipeEntry>) -> Void) {
        let entry = currentEntry()
        let next = Date().addingTimeInterval(refreshInterval)
        let timeline = Timeline(entries: [entry], policy: .after(next))
        completion(timeline)
    }

    // MARK: - Private

    private func currentEntry() -> FeaturedRecipeEntry {
        let snapshot = store?.read()
        let first = snapshot?.entries.first
        return FeaturedRecipeEntry(date: Date(), recipe: first)
    }
}

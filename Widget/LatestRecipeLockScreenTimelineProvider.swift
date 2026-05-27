import DODSupport
import Foundation
import WidgetKit

/// Single timeline entry shown by the latest-recipe lock-screen widget.
/// Wraps a ``WidgetSnapshot/Entry?`` so the same view can render the
/// populated and placeholder states.
///
/// `nil` means the widget renders the empty-state placeholder
/// (AC-22.4) — first launch, App Group unavailable in a non-provisioned
/// build, or persisted snapshot version mismatch.
struct LatestRecipeLockScreenEntry: TimelineEntry {

    /// Schedule slot WidgetKit hands to the view.
    let date: Date

    /// `nil` means show the placeholder (AC-22.4).
    let recipe: WidgetSnapshot.Entry?

    /// WidgetKit gallery / redacted-preview entry. The gallery preview
    /// uses a representative populated state so the user can recognize
    /// the widget while picking a Lock Screen layout.
    static let placeholder = LatestRecipeLockScreenEntry(
        date: Date(timeIntervalSince1970: 1_700_000_000),
        recipe: .init(
            id: 0,
            title: "Garlic Butter Skillet Corn",
            excerpt: "An easy 15-minute side dish that pairs with everything.",
            heroImageURL: nil,
            canonicalURL: nil,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            totalTimeDisplay: nil
        )
    )
}

/// Reads the App-Group featured-widget snapshot (same one the home-
/// screen `FeaturedRecipeWidget` reads — see CL-37 for why the
/// lock-screen widget reuses it rather than introducing a new wire
/// format) and produces a timeline. Mirrors
/// ``FeaturedRecipeTimelineProvider`` — same 4-hour fallback refresh,
/// same `reloadAllTimelines()` preempt from the host app after every
/// successful feed load (AC-9.3 already covers both widget kinds since
/// `reloadAllTimelines` is bundle-scoped, not kind-scoped).
struct LatestRecipeLockScreenTimelineProvider: TimelineProvider {

    /// Lazily-built reader. Initializer can fail if the App Group
    /// isn't provisioned (e.g. running the widget in a vanilla
    /// simulator slice without the entitlement) — in that case
    /// `read()` calls return nil and we surface the placeholder, which
    /// is the gracefully-degraded outcome AC-22.4 expects.
    private var store: WidgetSnapshotStore? {
        WidgetSnapshotStore()
    }

    /// How far ahead we schedule the next forced refresh in the
    /// absence of an explicit `reloadAllTimelines()` from the app.
    /// Matches the featured + saved widgets' cadence so all three
    /// kinds refresh in lockstep.
    private let refreshInterval: TimeInterval = 4 * 60 * 60

    func placeholder(in context: Context) -> LatestRecipeLockScreenEntry {
        // T-391/T-392 follow-up: WidgetKit calls `placeholder(in:)` first
        // for the gallery preview thumbnail — it does NOT necessarily call
        // `getSnapshot(in:completion:)` before painting the thumbnail.
        // Reading the snapshot synchronously here is cheap (UserDefaults
        // plist load, single-digit ms) and gives the gallery the user's
        // real latest recipe immediately (title + excerpt; hero image
        // doesn't apply on lock-screen per CL-37). Fall back to the
        // hardcoded brand placeholder only when the App Group is empty
        // (first launch before the feed has loaded). AC-22.4.
        let entry = currentEntry()
        return entry.recipe == nil ? .placeholder : entry
    }

    func getSnapshot(in context: Context, completion: @escaping (LatestRecipeLockScreenEntry) -> Void) {
        // Mirror the `placeholder(in:)` path: prefer the live snapshot,
        // fall back to the hardcoded brand placeholder only when the
        // App Group is empty. T-391.
        let entry = currentEntry()
        completion(entry.recipe == nil ? .placeholder : entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LatestRecipeLockScreenEntry>) -> Void) {
        let entry = currentEntry()
        let next = Date().addingTimeInterval(refreshInterval)
        let timeline = Timeline(entries: [entry], policy: .after(next))
        completion(timeline)
    }

    // MARK: - Private

    private func currentEntry() -> LatestRecipeLockScreenEntry {
        let snapshot = store?.read()
        let first = snapshot?.entries.first
        return LatestRecipeLockScreenEntry(date: Date(), recipe: first)
    }
}

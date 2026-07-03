import AppIntents
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

    /// DUT-485 / T-905 — the user-selected content mode, so the entry view can
    /// render the right eyebrow even when the shown entry's own `isArticle`
    /// flag doesn't reflect the chosen surface. Defaults to `.auto`.
    var content: LatestContent = .auto

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
///
/// DUT-485 / T-905 — now an `AppIntentTimelineProvider` sharing the same
/// ``LatestWidgetConfigurationIntent`` as the home-screen widget, so the
/// lock-screen "Latest" widget is user-configurable (Auto / Recipes /
/// Articles) too. Default `.auto` reproduces the prior behaviour.
struct LatestRecipeLockScreenTimelineProvider: AppIntentTimelineProvider {

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
        // No configuration in `placeholder(in:)` — read in `.auto`. Reading the
        // snapshot synchronously here is cheap (UserDefaults plist load) and
        // gives the gallery the user's real latest post (title + excerpt; hero
        // image doesn't apply on lock-screen per CL-37). Fall back to the
        // hardcoded brand placeholder only when the App Group is empty. AC-22.4.
        let entry = currentEntry(for: .auto)
        return entry.recipe == nil ? .placeholder : entry
    }

    func snapshot(
        for configuration: LatestWidgetConfigurationIntent,
        in context: Context
    ) async -> LatestRecipeLockScreenEntry {
        // Mirror the `placeholder(in:)` path: prefer the live snapshot,
        // fall back to the brand placeholder only when the selected mode
        // yields nothing. T-391 / DUT-504.
        fallbackIfEmpty(currentEntry(for: configuration.content))
    }

    func timeline(
        for configuration: LatestWidgetConfigurationIntent,
        in context: Context
    ) async -> Timeline<LatestRecipeLockScreenEntry> {
        let entry = fallbackIfEmpty(currentEntry(for: configuration.content))
        let next = Date().addingTimeInterval(refreshInterval)
        return Timeline(entries: [entry], policy: .after(next))
    }

    // MARK: - Private

    private func currentEntry(for content: LatestContent) -> LatestRecipeLockScreenEntry {
        let snapshot = store?.read()
        let selected = content.entry(from: snapshot)
        return LatestRecipeLockScreenEntry(date: Date(), recipe: selected, content: content)
    }

    /// DUT-504 — resolve the empty case. `.auto` / `.recipes` keep the
    /// hardcoded brand RECIPE placeholder so the gallery / first-launch look is
    /// unchanged. `.articles` with no article keeps `recipe: nil` (carrying the
    /// `.articles` mode) so the entry view shows the honest "no articles yet"
    /// empty tile routing to `dod://feed`, rather than the fabricated
    /// "Garlic Butter Skillet Corn" recipe whose `dod://recipe/0` tap is dead.
    private func fallbackIfEmpty(_ entry: LatestRecipeLockScreenEntry) -> LatestRecipeLockScreenEntry {
        guard entry.recipe == nil else { return entry }
        if entry.content == .articles {
            return LatestRecipeLockScreenEntry(date: entry.date, recipe: nil, content: .articles)
        }
        return .placeholder
    }
}

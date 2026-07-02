import DODDesignSystem
import DODSupport
import SwiftUI
import WidgetKit

/// "Saved Recipes" — `.accessoryCircular` Lock Screen shortcut. Sits
/// alongside the home-screen ``SavedRecipesWidget`` (US-17) and the
/// rectangular latest-recipe ``LatestRecipeLockScreenWidget`` (US-22) in
/// ``DODAppWidgetBundle``.
///
/// Unlike the other widgets this one carries NO data — it's a static
/// shortcut: a single `bookmark.fill` glyph whose tap opens the Saved tab
/// (`dod://saved`, the same deep link the home-screen Saved widget's chrome
/// uses — no new parser grammar). So the `TimelineProvider` is trivial (one
/// fixed entry, `.never` refresh) and the widget + provider + entry view all
/// live in this one small file rather than the three-file split the
/// snapshot-reading `LatestRecipeLockScreenWidget` needs.
///
/// CL-37 deferred `.accessoryCircular` for the *latest recipe* (no good
/// single-glyph recipe payload); a bookmark shortcut IS that good payload.
///
/// Spec trace: spec.md US-22 (amended by CL-168), US-17 (Saved tab target),
/// AC-22.7 (circular Saved shortcut).
struct SavedLockScreenWidget: Widget {

    /// Stable identifier WidgetKit uses to address this widget kind. Mirrors
    /// the dotted-bundle-style ids the other widgets use so the bundle forms
    /// a uniform set.
    static let kind = "com.dutchovendaddy.DODApp.Widget.SavedLockScreen"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: SavedLockScreenTimelineProvider()) { entry in
            SavedLockScreenWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    // The translucent, wallpaper-aware disc the system draws
                    // behind circular accessory content. Without it the glyph
                    // would float on bare wallpaper.
                    AccessoryWidgetBackground()
                }
        }
        .configurationDisplayName("Saved Recipes")
        .description("Tap to open your saved recipes.")
        .supportedFamilies([.accessoryCircular])
        // No configurable parameters — same as the other widgets.
        .contentMarginsDisabled()
    }
}

/// Timeline entry carrying the saved-recipe count (DUT-453) shown inside the
/// bookmark. Sourced from the saved-recipes App Group snapshot's true total.
struct SavedLockScreenEntry: TimelineEntry {
    let date: Date
    let savedCount: Int
}

/// Reads the saved-recipes snapshot's true total (DUT-453) so the bookmark can
/// badge the count. The host app force-reloads this widget kind whenever the
/// saved set changes (see `SavedRecipesWidgetPublisher`); a modest periodic
/// fallback covers cross-device (CloudKit) saves that don't route through the
/// local publisher.
struct SavedLockScreenTimelineProvider: TimelineProvider {

    private func savedCount() -> Int {
        WidgetSnapshotStore()?.readSavedRecipes()?.displayCount ?? 0
    }

    func placeholder(in context: Context) -> SavedLockScreenEntry {
        SavedLockScreenEntry(date: Date(), savedCount: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (SavedLockScreenEntry) -> Void) {
        completion(SavedLockScreenEntry(date: Date(), savedCount: savedCount()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SavedLockScreenEntry>) -> Void) {
        let entry = SavedLockScreenEntry(date: Date(), savedCount: savedCount())
        // 6-hour fallback refresh; real changes arrive via the app's explicit
        // reload after a save/unsave.
        let next = Date().addingTimeInterval(6 * 60 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

/// The circular face: the design-system `bookmark.fill` glyph (now badged with
/// the saved count, DUT-453) opted into the system accent tint pass
/// (`.widgetAccentable`), tapping through to the Saved tab via `dod://saved`
/// (already covered by US-9's `WidgetDeepLinkParser` — no new parser case).
struct SavedLockScreenWidgetEntryView: View {

    let entry: SavedLockScreenEntry

    var body: some View {
        WidgetCard.LockScreenCircularBookmark(count: entry.savedCount)
            .widgetAccentable()
            .widgetURL(URL(string: "dod://saved"))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Self.accessibilityLabel(for: entry.savedCount))
    }

    static func accessibilityLabel(for count: Int) -> String {
        switch count {
        case 0: return "Saved recipes. Open your saved recipes."
        case 1: return "Saved recipes. 1 saved. Open your saved recipes."
        default: return "Saved recipes. \(count) saved. Open your saved recipes."
        }
    }
}

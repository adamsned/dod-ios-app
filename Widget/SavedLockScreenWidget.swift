import DODDesignSystem
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
        StaticConfiguration(kind: Self.kind, provider: SavedLockScreenTimelineProvider()) { _ in
            SavedLockScreenWidgetEntryView()
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

/// Single fixed timeline entry — the widget is a static shortcut with no
/// per-time content, so one entry with a `.never` refresh policy is all the
/// timeline needs.
struct SavedLockScreenEntry: TimelineEntry {
    let date: Date
}

/// Trivial provider: the widget shows the same `bookmark.fill` shortcut at
/// all times, so every callback returns one fixed entry and the timeline
/// never needs to refresh (`.never`). No App Group read, no snapshot.
struct SavedLockScreenTimelineProvider: TimelineProvider {

    func placeholder(in context: Context) -> SavedLockScreenEntry {
        SavedLockScreenEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SavedLockScreenEntry) -> Void) {
        completion(SavedLockScreenEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SavedLockScreenEntry>) -> Void) {
        completion(Timeline(entries: [SavedLockScreenEntry(date: Date())], policy: .never))
    }
}

/// The circular face: the design-system `bookmark.fill` glyph opted into the
/// system accent tint pass (`.widgetAccentable`), tapping through to the
/// Saved tab via `dod://saved` (already covered by US-9's
/// `WidgetDeepLinkParser` — no new parser case).
struct SavedLockScreenWidgetEntryView: View {

    var body: some View {
        WidgetCard.LockScreenCircularBookmark()
            .widgetAccentable()
            .widgetURL(URL(string: "dod://saved"))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Saved recipes. Open your saved recipes.")
    }
}

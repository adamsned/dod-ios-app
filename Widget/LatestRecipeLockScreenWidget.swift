import DODDesignSystem
import DODSupport
import SwiftUI
import WidgetKit

/// "Latest Recipe" — `.accessoryRectangular` lock-screen widget. Sits
/// alongside ``FeaturedRecipeWidget`` (US-9, home screen) and
/// ``SavedRecipesWidget`` (US-17, home screen) in ``DODAppWidgetBundle``.
///
/// The TimelineProvider reads the **same featured-widget snapshot** the
/// home-screen widget reads — no new snapshot file, no new App Group
/// key, no new host-side observer. The host app's existing post-feed-
/// load `WidgetSnapshotStore.write(...)` call (in `FeedViewModel`)
/// already updates the lock-screen widget the same way it updates the
/// home-screen one. See CL-37 for the reuse rationale.
///
/// Lock-screen widgets render text-only, monochrome — the system tints
/// the rendered glyphs and text against the user's Lock Screen
/// wallpaper at present-time. No image rendering, no chips. Tap on a
/// populated entry → `dod://recipe/<id>` (existing US-9 parser case);
/// tap on the empty-state placeholder → `dod://feed` (also existing).
///
/// Configuration choice: `AppIntentConfiguration` (DUT-485 / T-905) sharing
/// the home-screen widget's ``LatestWidgetConfigurationIntent`` so long-press →
/// Edit Widget lets the user pick Auto / Recipes / Articles here too. Default
/// `.auto` reproduces the prior always-latest behaviour.
///
/// Spec trace: spec.md US-22, AC-22.1, AC-22.2, AC-22.3, AC-22.4; DUT-485 / T-905.
struct LatestRecipeLockScreenWidget: Widget {

    /// Stable identifier WidgetKit uses to address this widget kind.
    /// Mirrors the dotted-bundle-style id used by `FeaturedRecipeWidget`
    /// so the three kinds form a uniform set when the host app calls
    /// `WidgetCenter.shared.reloadTimelines(ofKind:)`.
    static let kind = "com.dutchovendaddy.DODApp.Widget.LatestRecipeLockScreen"

    var body: some WidgetConfiguration {
        // DUT-485 / T-905 — `AppIntentConfiguration` (was `StaticConfiguration`)
        // with the shared ``LatestWidgetConfigurationIntent``. `Self.kind` stays
        // unchanged so installed widgets keep their identity; the migration
        // defaults to `.auto`.
        AppIntentConfiguration(
            kind: Self.kind,
            intent: LatestWidgetConfigurationIntent.self,
            provider: LatestRecipeLockScreenTimelineProvider()
        ) { entry in
            LatestRecipeLockScreenWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    // Lock-screen rectangular widgets paint over a
                    // system-managed background — the
                    // `AccessoryWidgetBackground` rendering pass
                    // handles wallpaper-aware tinting. Empty background
                    // closure is the documented signal to defer to
                    // that system behaviour.
                    Color.clear
                }
        }
        .configurationDisplayName("Latest")
        .description("See the latest Dutch Oven Daddy recipe on your Lock Screen.")
        // CL-37: `.accessoryRectangular` only. `.accessoryCircular`
        // (no good single-glyph payload for a recipe) and
        // `.accessoryInline` (shared rate-limited inline slot) are
        // explicitly out of scope.
        .supportedFamilies([.accessoryRectangular])
        .contentMarginsDisabled()
    }
}

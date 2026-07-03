import DODDesignSystem
import DODSupport
import SwiftUI
import WidgetKit

/// "Latest Recipe" — small + medium home-screen widget.
///
/// The TimelineProvider reads the snapshot the main app writes after every
/// successful feed load (see `FeedViewModel` → `WidgetSnapshotStore.write`).
/// Tap-through deep-links into the app via `dod://recipe/<id>` (handled by
/// `RootView.onOpenURL`).
///
/// The widget kind identifier (`Self.kind`) and the Swift type name
/// (`FeaturedRecipeWidget`) intentionally stay unchanged across the
/// "Today's Recipe" → "Latest Recipe" rename (CL-36) so existing
/// `WidgetCenter.shared.reloadAllTimelines()` plumbing and the
/// `widgetOpened(kind: "featured", recipeID:)` analytics call site
/// (AC-17.9) keep working without parallel renames. Only the
/// user-visible display name moves.
///
/// Spec trace: spec.md US-9 (original widget), US-21 / AC-21.1 (rename),
/// AC-21.3 (real hero image via the WidgetImageBridge file pathway); DUT-485 /
/// T-905 (rename to "Latest" + user-configurable content mode).
struct FeaturedRecipeWidget: Widget {

    static let kind = "com.dutchovendaddy.DODApp.Widget.FeaturedRecipe"

    var body: some WidgetConfiguration {
        // DUT-485 / T-905 — `AppIntentConfiguration` (was `StaticConfiguration`)
        // so long-press → Edit Widget lets the user pick Auto / Recipes /
        // Articles via ``LatestWidgetConfigurationIntent``. `Self.kind` is
        // unchanged so existing installed widgets keep their identity; the
        // migration defaults to `.auto`, i.e. today's behaviour.
        AppIntentConfiguration(
            kind: Self.kind,
            intent: LatestWidgetConfigurationIntent.self,
            provider: FeaturedRecipeTimelineProvider()
        ) { entry in
            FeaturedRecipeWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    // Widget background. The view itself paints over the
                    // hero image when there is one; this layer just keeps
                    // the placeholder state readable.
                    DODColor.surfaceElevated
                }
        }
        .configurationDisplayName("Latest")
        .description("See the latest Dutch Oven Daddy recipe right on your home screen.")
        // T-768 / CL-165 (DUT-74) — large added alongside small + medium.
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

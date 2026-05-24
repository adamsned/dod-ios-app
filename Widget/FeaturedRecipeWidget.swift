import DODDesignSystem
import DODSupport
import SwiftUI
import WidgetKit

/// "Today's Featured Recipe" — small + medium home-screen widget.
///
/// The TimelineProvider reads the snapshot the main app writes after every
/// successful feed load (see `FeedViewModel` → `WidgetSnapshotStore.write`).
/// Tap-through deep-links into the app via `dod://recipe/<id>` (handled by
/// `RootView.onOpenURL`).
///
/// Spec trace: spec.md US-9, AC-9.1, AC-9.2, AC-9.3, AC-9.4.
struct FeaturedRecipeWidget: Widget {

    static let kind = "com.dutchovendaddy.DODApp.Widget.FeaturedRecipe"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: FeaturedRecipeTimelineProvider()) { entry in
            FeaturedRecipeWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    // Widget background. The view itself paints over the
                    // hero image when there is one; this layer just keeps
                    // the placeholder state readable.
                    DODColor.surfaceElevated
                }
        }
        .configurationDisplayName("Today's Recipe")
        .description("See the latest Dutch Oven Daddy recipe right on your home screen.")
        .supportedFamilies([.systemSmall, .systemMedium])
        // The widget itself contains no content the user can edit, so we
        // don't need a configuration intent.
        .contentMarginsDisabled()
    }
}

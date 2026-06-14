import DODDesignSystem
import DODSupport
import SwiftUI
import WidgetKit

/// "Saved Recipes" — small + medium home-screen widget. Sits alongside
/// ``FeaturedRecipeWidget`` in ``DODAppWidgetBundle``.
///
/// The TimelineProvider reads the snapshot the main app writes after every
/// SavedStore mutation (see T-322 for the host-side wiring). Tap on a
/// recipe row → `dod://recipe/<id>`; tap on widget chrome (whitespace or
/// the empty-state placeholder) → `dod://saved` (US-17 CL-29 / AC-17.4).
///
/// Spec trace: spec.md US-17, AC-17.1, AC-17.2, AC-17.4, AC-17.5, AC-17.6.
struct SavedRecipesWidget: Widget {

    /// Stable identifier the host app passes to
    /// `WidgetCenter.shared.reloadTimelines(ofKind:)` on every saved-set
    /// mutation (T-322). The string is matched verbatim across processes —
    /// see AC-17.6.
    static let kind = "SavedRecipesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: SavedRecipesTimelineProvider()) { entry in
            SavedRecipesWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    // Same surface treatment as the featured widget so
                    // both kinds visually share the same chrome on the
                    // home screen.
                    DODColor.surfaceElevated
                }
        }
        .configurationDisplayName("Saved Recipes")
        .description("Quick access to your saved recipes.")
        // T-768 / CL-165 (DUT-74) — large added (supersedes CL-26's
        // small+medium-only deferral); the large face shows up to 5 rows.
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        // The widget extension has no configurable parameters — no intent
        // needed, same as the featured widget.
        .contentMarginsDisabled()
    }
}

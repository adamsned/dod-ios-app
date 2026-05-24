import DODDesignSystem
import DODSupport
import SwiftUI
import WidgetKit

/// Routes between empty-state placeholder, small (1 row), and medium
/// (up to 3 rows) layouts based on the widget family the user installed.
///
/// The visual layer lives in ``DODDesignSystem/WidgetCard``'s `Saved*`
/// variants so it can be snapshot-tested without linking WidgetKit
/// (constitution §6 L4). This file owns the WidgetKit-specific glue:
/// per-row ``Link`` tap targets for `dod://recipe/<id>`, and a chrome-
/// level ``widgetURL`` fallback to `dod://saved` (CL-29 / AC-17.4).
struct SavedRecipesWidgetEntryView: View {

    @Environment(\.widgetFamily) private var family
    let entry: SavedRecipesEntry

    var body: some View {
        Group {
            if entry.entries.isEmpty {
                WidgetCard.SavedEmpty()
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        "No saved recipes yet. Tap to open the Saved tab."
                    )
            } else {
                switch family {
                case .systemMedium:
                    mediumBody
                default:
                    smallBody
                }
            }
        }
        // Single chrome-level URL resolved from the current widget
        // family + payload. The small widget's whole face IS one recipe
        // row, so the entire tap target deep-links to that recipe.
        // The medium widget overrides this per-row via `Link` for each
        // recipe; gaps between rows fall through here to `dod://saved`
        // (CL-29 / AC-17.4).
        .widgetURL(chromeURL)
    }

    /// URL the whole-widget tap routes to. Per-row `Link`s in
    /// `mediumBody` override this for their hit regions only.
    private var chromeURL: URL? {
        switch family {
        case .systemSmall:
            // Small holds exactly one recipe — tap face → that recipe.
            return entry.entries.first.flatMap { Self.deepLink(for: $0) }
                ?? Self.savedFallbackURL
        default:
            // Medium + empty state: tap chrome → Saved tab.
            return Self.savedFallbackURL
        }
    }

    // MARK: - Small (1 entry)

    private var smallBody: some View {
        let first = entry.entries.first
        return WidgetCard.SavedSmall(row: Self.row(from: first))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Self.smallAccessibilityLabel(for: first))
    }

    // MARK: - Medium (up to 3 entries)

    /// Per-row links override the outer `widgetURL` for their hit region
    /// only — taps in the gaps between rows fall through to the chrome's
    /// `dod://saved` (CL-29). The row primitive itself comes from the
    /// design system so the layout stays in one place.
    private var mediumBody: some View {
        VStack(alignment: .leading, spacing: DODSpacing.xs) {
            Text("Saved")
                .font(.system(.caption2, design: .default, weight: .semibold))
                .foregroundStyle(DODColor.burntOrange)
                .textCase(.uppercase)
                .tracking(0.5)

            VStack(spacing: DODSpacing.xs) {
                ForEach(Array(entry.entries.prefix(3))) { snapshotEntry in
                    let url = Self.deepLink(for: snapshotEntry) ?? Self.savedFallbackURL
                    Link(destination: url) {
                        WidgetCard.SavedListRow(row: Self.row(from: snapshotEntry))
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Self.rowAccessibilityLabel(for: snapshotEntry))
                }
                if entry.entries.count < 3 {
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(DODSpacing.sm)
        .background(DODColor.surfaceElevated)
    }

    /// Fallback used when URL construction somehow fails — a `dod://`
    /// literal that the host parser will route to the Saved tab, the
    /// same place a chrome tap would land. Force-unwrap is guarded by
    /// the literal being parser-verified (`URL(string:)` never returns
    /// nil for a valid absolute URI string) and the swiftlint exception
    /// here mirrors the same allowance the existing
    /// FeaturedRecipeWidget entry view takes for its feed fallback.
    private static let savedFallbackURL = URL(string: "dod://saved") ?? URL(fileURLWithPath: "/")

    // MARK: - Helpers

    /// Build a `dod://recipe/<id>` URL for tap-through. Mirrors
    /// `FeaturedRecipeWidgetEntryView.deepLink(for:)` so both widgets
    /// emit identical recipe URLs.
    static func deepLink(for entry: SavedRecipesWidgetSnapshot.Entry) -> URL? {
        var components = URLComponents()
        components.scheme = "dod"
        components.host = "recipe"
        components.path = "/\(entry.recipeID)"
        return components.url
    }

    static func row(from snapshotEntry: SavedRecipesWidgetSnapshot.Entry?) -> WidgetCard.SavedRow {
        guard let snapshotEntry else {
            return WidgetCard.SavedRow(title: "")
        }
        return WidgetCard.SavedRow(
            title: snapshotEntry.title,
            // The saved-snapshot schema carries a *filename* the host app
            // wrote into the App Group container, not a URL. The widget
            // resolves it into a `file://` URL pointing at that container
            // path; if the App Group isn't reachable (e.g. simulator
            // without the entitlement) we fall back to nil and let
            // `WidgetCard.Hero` render its gradient placeholder.
            heroImageURL: snapshotEntry.heroImageFilename.flatMap(Self.heroImageURL(forFilename:))
        )
    }

    /// Map a cached hero filename onto a `file://` URL inside the shared
    /// App Group container. Returns nil if the container can't be
    /// located (no entitlement / wrong simulator slice) so the row
    /// renders its gradient fallback instead of crashing.
    static func heroImageURL(forFilename filename: String) -> URL? {
        guard
            let container = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: WidgetSnapshotConfig.appGroupIdentifier
            )
        else { return nil }
        return container.appendingPathComponent(filename, isDirectory: false)
    }

    static func smallAccessibilityLabel(for entry: SavedRecipesWidgetSnapshot.Entry?) -> String {
        guard let entry else {
            return "Saved recipes widget. No saved recipes yet."
        }
        return "Saved recipe: \(entry.title)."
    }

    static func rowAccessibilityLabel(for entry: SavedRecipesWidgetSnapshot.Entry) -> String {
        "Saved recipe: \(entry.title)."
    }
}


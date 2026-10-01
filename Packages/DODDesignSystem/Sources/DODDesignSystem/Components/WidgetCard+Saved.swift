import SwiftUI

// Saved-recipes widget variants of ``WidgetCard``. Lives in its own file
// alongside the featured-widget primitives in `WidgetCard.swift` so the
// type stays under SwiftLint's 250-line cap.
//
// The saved-recipes widget renders a list, not a hero. Each row is a
// 36pt-square thumbnail + a one-/two-line title. Small holds one row,
// medium holds three. Tap targets are wired by the entry view via
// `Link(destination:)` per row so each row deep-links to its own
// `dod://recipe/<id>`; the widget chrome falls through to `dod://saved`
// (CL-29 / AC-17.4).
//
// Spec trace: spec.md US-17, AC-17.5 (empty state), AC-17.7 (snapshot
// coverage in `SnapshotTests`).
extension WidgetCard {

    /// Plain-old-data input for a single saved-recipe row. Mirrors the
    /// fields ``SavedRecipesWidgetSnapshot.Entry`` exposes to the
    /// renderer (DODSupport) — we keep the design system free of any
    /// DODSupport dependency so this layer can be snapshot-tested in
    /// isolation.
    public struct SavedRow: Equatable, Sendable {
        public let title: String
        public let heroImageURL: URL?

        public init(title: String, heroImageURL: URL? = nil) {
            self.title = title
            self.heroImageURL = heroImageURL
        }
    }

    /// Small saved-widget layout (DUT-1381): the most recently saved recipe's
    /// photo with its name centred over it, the same look as the Latest small
    /// widget (``Small``), so a long name is never squeezed into a narrow
    /// title column beside a thumbnail. Tinted/Vibrant handling comes from
    /// ``Small`` (title on the container, DUT-9). Caller passes the saved rows
    /// newest-first; only the first is shown.
    public struct SavedSmall: View {

        public let rows: [SavedRow]

        public init(rows: [SavedRow]) {
            self.rows = rows
        }

        /// The small size shows a single recipe.
        public static let maxRows = 1

        public var body: some View {
            if let row = rows.first {
                Small(content: Content(title: row.title, excerpt: "", heroImageURL: row.heroImageURL))
            }
        }
    }

    /// Wide medium-widget layout: up to three saved-recipe rows stacked
    /// with a thumbnail-left / title-right shape. Caller is responsible
    /// for trimming the array to at most 3 entries.
    public struct SavedMedium: View {

        public let rows: [SavedRow]

        public init(rows: [SavedRow]) {
            self.rows = rows
        }

        public var body: some View {
            VStack(alignment: .leading, spacing: DODSpacing.xs) {
                Text("Saved")
                    .font(.system(.caption2, design: .default, weight: .semibold))
                    .foregroundStyle(DODColor.burntOrange)
                    .textCase(.uppercase)
                    .tracking(0.5)

                VStack(spacing: DODSpacing.xs) {
                    ForEach(Array(rows.prefix(3).enumerated()), id: \.offset) { _, row in
                        SavedListRow(row: row)
                    }
                    // Pad short payloads (e.g. only 1 saved) so the
                    // remaining row slots stay blank rather than the rows
                    // we have stretching to fill — keeps spacing stable
                    // between 1-saved and 3-saved snapshots.
                    if rows.count < 3 {
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(DODSpacing.sm)
            // T-767 / CL-164 — background owned by `containerBackground` (Tinted-safe).
        }
    }

    /// AC-17.5 / CL-27: shown when the saved set is empty. Distinct
    /// from the featured-widget ``Placeholder`` so the copy can name
    /// the saved surface specifically ("Save a recipe to see it here")
    /// and the caller can wire the tap target to `dod://saved`.
    public struct SavedEmpty: View {

        public init() {}

        public var body: some View {
            VStack(alignment: .leading, spacing: DODSpacing.xs) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(DODColor.burntOrange)
                Text("Saved Recipes")
                    .font(.system(.headline, design: .default, weight: .semibold))
                    .foregroundStyle(DODColor.label)
                Text("Save a recipe to see it here.")
                    .font(.system(.caption, design: .default))
                    .foregroundStyle(DODColor.labelSecondary)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(DODSpacing.md)
            // T-767 / CL-164 — background owned by `containerBackground` (Tinted-safe).
        }
    }

    /// One row inside ``SavedMedium``. A 36pt-square thumbnail with the
    /// recipe title to its right. Public so the widget entry view can
    /// wrap an individual row in a ``Link`` for per-row tap-through
    /// (US-17 CL-29 / AC-17.4) without duplicating the layout
    /// primitives.
    public struct SavedListRow: View {

        public let row: SavedRow

        public init(row: SavedRow) {
            self.row = row
        }

        public var body: some View {
            HStack(spacing: DODSpacing.xs) {
                Hero(url: row.heroImageURL)
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: DODRadius.widgetThumbnail, style: .continuous))

                Text(row.title)
                    .font(.system(.footnote, design: .default, weight: .semibold))
                    .foregroundStyle(DODColor.label)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)
            }
        }
    }
}

#Preview("Saved Small") {
    WidgetCard.SavedSmall(
        rows: [
            .init(title: "Garlic Butter Skillet Corn"),
            .init(title: "Sourdough Bread"),
        ]
    )
    .frame(width: 158, height: 158)
}

#Preview("Saved Medium 3-row") {
    WidgetCard.SavedMedium(
        rows: [
            .init(title: "Garlic Butter Skillet Corn"),
            .init(title: "Sourdough Bread"),
            .init(title: "Cast Iron Pizza"),
        ]
    )
    .frame(width: 338, height: 158)
}

#Preview("Saved Empty") {
    WidgetCard.SavedEmpty()
        .frame(width: 158, height: 158)
}

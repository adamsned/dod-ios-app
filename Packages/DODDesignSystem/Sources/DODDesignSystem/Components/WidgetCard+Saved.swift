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

    /// Compact small-widget layout: one saved-recipe row centred in the
    /// 158×158pt frame.
    public struct SavedSmall: View {

        public let row: SavedRow

        public init(row: SavedRow) {
            self.row = row
        }

        public var body: some View {
            VStack(alignment: .leading, spacing: DODSpacing.xs) {
                Text("Saved")
                    .font(.system(.caption2, design: .default, weight: .semibold))
                    .foregroundStyle(DODColor.burntOrange)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Spacer(minLength: 0)

                Hero(url: row.heroImageURL)
                    .frame(height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text(row.title)
                    .font(.system(.subheadline, design: .default, weight: .semibold))
                    .foregroundStyle(DODColor.label)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(DODSpacing.sm)
            // T-767 / CL-164 — background owned by `containerBackground` (Tinted-safe).
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
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

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
        row: .init(title: "Garlic Butter Skillet Corn", heroImageURL: nil)
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

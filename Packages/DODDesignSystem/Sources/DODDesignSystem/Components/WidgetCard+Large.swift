import SwiftUI

// T-768 / CL-165 (DUT-74) — `.systemLarge` variants of ``WidgetCard``.
// Split into their own file (like `WidgetCard+Saved.swift`) so the core
// `WidgetCard.swift` stays under SwiftLint's type/file-length caps.
//
// Both large layouts follow the PR2 (CL-164) rule: NO inner background —
// the widget's `containerBackground(for: .widget)` owns it so Tinted/Clear
// mode tints the background while the hero/thumbnail photos keep their
// `fullColor` opt-out (inside ``WidgetCard/Hero``). Text renders on the
// container (not over the image), so it stays legible in `.accented` mode
// without a scrim (AC-23.7 — the scrim is only needed for text-over-image,
// which the large layouts deliberately avoid).
//
// Spec trace: spec.md US-9 (featured), US-17 (saved), US-23 (tinted).
extension WidgetCard {

    /// Large featured-widget layout: a big hero photo on top with the
    /// eyebrow + title + excerpt + time chip stacked beneath it on the
    /// (tint-aware) container background. Photo-forward "magazine cover"
    /// shape, distinct from the medium's side-by-side split.
    public struct FeaturedLarge: View {

        public let content: Content

        public init(content: Content) {
            self.content = content
        }

        public var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                Hero(url: content.heroImageURL)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                VStack(alignment: .leading, spacing: DODSpacing.xs) {
                    Text("New on DOD")
                        .font(.system(.caption2, design: .default, weight: .semibold))
                        .foregroundStyle(DODColor.burntOrange)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    Text(content.title)
                        .font(.system(.headline, design: .default, weight: .semibold))
                        .foregroundStyle(DODColor.label)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .multilineTextAlignment(.leading)

                    if !content.excerpt.isEmpty {
                        Text(content.excerpt)
                            .font(.system(.subheadline, design: .default))
                            .foregroundStyle(DODColor.labelSecondary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .multilineTextAlignment(.leading)
                    }

                    if let totalTime = content.totalTimeDisplay {
                        TimeChip(text: totalTime)
                            .padding(.top, DODSpacing.xxs)
                    }
                }
                // DUT-458 — the content region wins its space over the greedy
                // hero (`.layoutPriority(1)`, replacing DUT-75's `.fixedSize`
                // which forced the natural height and could push the last line /
                // time chip past the frame with long real-world content or large
                // Dynamic Type). The `.minimumScaleFactor(0.7)` on the title +
                // excerpt then shrinks text to fit instead of clipping; the hero
                // shrinks toward the remainder.
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DODSpacing.md)
                .layoutPriority(1)
            }
        }
    }

    /// Large saved-widget layout: the "Saved" eyebrow + up to five
    /// thumbnail rows (vs. the medium's three). Caller is responsible for
    /// trimming the array to at most five entries.
    public struct SavedLarge: View {

        public let rows: [SavedRow]

        public init(rows: [SavedRow]) {
            self.rows = rows
        }

        /// Max rows the large size renders. Mirrors the medium's cap of 3.
        public static let maxRows = 5

        public var body: some View {
            VStack(alignment: .leading, spacing: DODSpacing.sm) {
                Text("Saved")
                    .font(.system(.caption2, design: .default, weight: .semibold))
                    .foregroundStyle(DODColor.burntOrange)
                    .textCase(.uppercase)
                    .tracking(0.5)

                VStack(spacing: DODSpacing.sm) {
                    ForEach(Array(rows.prefix(Self.maxRows).enumerated()), id: \.offset) { _, row in
                        SavedListRow(row: row)
                    }
                    // Pad short payloads so rows top-align instead of
                    // stretching to fill the taller large frame.
                    if rows.count < Self.maxRows {
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(DODSpacing.sm)
        }
    }
}

#Preview("Featured Large") {
    WidgetCard.FeaturedLarge(
        content: .init(
            title: "Garlic Butter Skillet Corn",
            excerpt: "An easy 15-minute side dish that pairs with everything.",
            heroImageURL: nil,
            totalTimeDisplay: "15 min"
        )
    )
    .frame(width: 364, height: 382)
}

#Preview("Saved Large") {
    WidgetCard.SavedLarge(
        rows: [
            .init(title: "Garlic Butter Skillet Corn"),
            .init(title: "Sourdough Bread"),
            .init(title: "Cast Iron Pizza"),
            .init(title: "Dutch Oven Chili"),
            .init(title: "Skillet Cornbread"),
        ]
    )
    .frame(width: 364, height: 382)
}

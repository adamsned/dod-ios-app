import DODSupport
import SwiftUI

// MARK: - List row variant (US-38 / AC-38.4 / CL-64, T-650)

extension RecipeCard {

    /// US-38 / AC-38.4 / CL-64.4 (T-650, 2026-05-27) — dense single-column
    /// row variant. Hosted as a `RecipeCard` extension (split to its own file
    /// for the SwiftLint file-length cap, T-782); shares the time-chip body + the same `DODColor.surfaceElevated`
    /// background; lives as a nested struct so call sites read
    /// `RecipeCard.ListRow(...)` and the affinity to the gallery card is
    /// visible at the API surface.
    ///
    /// Layout (CL-64.4):
    ///   - 60×60pt `AsyncImage` thumbnail on the leading edge, clipped to
    ///     a `RoundedRectangle(cornerRadius: DODRadius.inner)`.
    ///   - `VStack(.leading)` carrying the title (`.lineLimit(2)` — DUT-527,
    ///     so large Dynamic Type doesn't truncate the name;
    ///     `DODType.heading`) and the excerpt (`.lineLimit(1)`,
    ///     `DODType.caption`). The excerpt is single-line in the row
    ///     variant to keep the density (gallery card uses 2 lines).
    ///   - Optional time chip on the trailing edge — only rendered when
    ///     `totalTimeDisplay` is non-nil.
    ///   - `DODSpacing.sm` vertical padding around the row.
    ///   - `DODColor.surfaceElevated` background inside a
    ///     `RoundedRectangle(cornerRadius: DODRadius.standard)` (matches the
    ///     gallery card's surface treatment).
    ///
    /// Composes with the same ``recipeCardTap(_:)`` +
    /// ``recipeCardContextMenu(isSaved:onToggle:)`` modifiers the gallery
    /// card uses, so the row's tap + long-press semantics are
    /// byte-identical (AC-34.1 / AC-34.6 preserved).
    public struct ListRow: View {

        public let title: String
        public let excerpt: String
        public let heroImageURL: URL?
        public let totalTimeDisplay: String?
        /// Active search query (DUT-10) — see ``RecipeCard/highlightQuery``.
        public let highlightQuery: String?

        public init(
            title: String,
            excerpt: String,
            heroImageURL: URL?,
            totalTimeDisplay: String? = nil,
            highlightQuery: String? = nil
        ) {
            self.title = title
            self.excerpt = excerpt
            self.heroImageURL = heroImageURL
            self.totalTimeDisplay = totalTimeDisplay
            self.highlightQuery = highlightQuery
        }

        public var body: some View {
            HStack(alignment: .center, spacing: DODSpacing.sm) {
                thumbnail
                VStack(alignment: .leading, spacing: DODSpacing.xxs) {
                    RecipeCard.titleText(title, highlightQuery: highlightQuery)
                        .dodFont(DODType.heading)
                        .foregroundStyle(DODColor.label)
                        // DUT-527 — allow 2 title lines on compact (iPhone) too,
                        // matching the gallery card, so larger Dynamic Type sizes
                        // no longer truncate recipe names to "Veget…".
                        .lineLimit(2)
                    Text(excerpt)
                        .dodFont(DODType.caption)
                        .foregroundStyle(DODColor.labelSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let totalTimeDisplay {
                    RecipeCard.timeChip(totalTimeDisplay)
                }
            }
            .padding(.horizontal, DODSpacing.sm)
            .padding(.vertical, DODSpacing.sm)
            .background(DODColor.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous))
        }

        /// 60×60pt leading thumbnail. AsyncImage states map to the same
        /// loading / failure visuals the gallery card uses, scaled down
        /// to the smaller frame. Hidden from accessibility — the parent
        /// row's `recipeCardTap` modifier collapses children into the
        /// row's combined label.
        private var thumbnail: some View {
            // DUT-195 — reliable cached loader (see ReliableImage); AsyncImage
            // was failing these thumbnails to the broken-image placeholder.
            ReliableImage(url: heroImageURL) { phase in
                switch phase {
                case .empty:
                    LoadingSkeleton(cornerRadius: DODRadius.inner)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Image(systemName: "photo")
                        .foregroundStyle(DODColor.labelSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(DODColor.surface)
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: DODRadius.inner, style: .continuous))
            .accessibilityHidden(true)
        }
    }
}

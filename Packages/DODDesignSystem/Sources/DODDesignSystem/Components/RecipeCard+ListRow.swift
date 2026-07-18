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
        /// DUT-530 — when true, a compact download glyph sits beside the title
        /// so the list layout matches the gallery card's "Downloaded" badge
        /// (``RecipeCard/isDownloaded``). Defaults `false`, so every existing
        /// call site (Feed/Search) and their L4 baselines render byte-identical;
        /// only the Saved tab's list rows pass the real downloaded state.
        public let isDownloaded: Bool
        /// US-43 Phase b (T-711) — the compositional register. `.classic` (the
        /// default) keeps every existing host + L4 baseline byte-identical; the
        /// Feed passes the resolved (default `.magazine`) variant, which steps up
        /// the thumbnail size + title weight for the editorial row.
        public let variant: DODFeed.LayoutVariant
        /// US-43 Phase c (T-712) — the numbered "Popular" rank shown as a small
        /// leading medallion. `nil` (default) renders none.
        public let popularRank: Int?

        public init(
            title: String,
            excerpt: String,
            heroImageURL: URL?,
            totalTimeDisplay: String? = nil,
            highlightQuery: String? = nil,
            isDownloaded: Bool = false,
            variant: DODFeed.LayoutVariant = .classic,
            popularRank: Int? = nil
        ) {
            self.title = title
            self.excerpt = excerpt
            self.heroImageURL = heroImageURL
            self.totalTimeDisplay = totalTimeDisplay
            self.highlightQuery = highlightQuery
            self.isDownloaded = isDownloaded
            self.variant = variant
            self.popularRank = popularRank
        }

        /// US-43 Phase b — the thumbnail edge length. `.magazine` steps the
        /// square thumbnail up from 60 to 72pt for a more editorial row; the
        /// `DODRadius.inner` clip is shared.
        private var thumbnailSize: CGFloat {
            switch variant {
            case .classic: 60
            case .magazine: 72
            }
        }

        /// US-43 Phase b — the title token. `.magazine` bolds to the Phase-a
        /// `DODType.displayMedium` (title2 `.bold`) to match the gallery card's
        /// editorial register; `.classic` keeps `.headline`.
        private var titleFont: Font {
            switch variant {
            case .classic: DODType.heading
            case .magazine: DODType.displayMedium
            }
        }

        public var body: some View {
            HStack(alignment: .center, spacing: DODSpacing.sm) {
                if let popularRank {
                    DODBadge.Numbered(number: popularRank)
                }
                thumbnail
                VStack(alignment: .leading, spacing: DODSpacing.xxs) {
                    HStack(alignment: .firstTextBaseline, spacing: DODSpacing.xxs) {
                        RecipeCard.titleText(title, highlightQuery: highlightQuery)
                            .dodFont(titleFont)
                            .foregroundStyle(DODColor.label)
                            // DUT-527 — allow 2 title lines on compact (iPhone) too,
                            // matching the gallery card, so larger Dynamic Type sizes
                            // no longer truncate recipe names to "Veget…".
                            .lineLimit(2)
                        // DUT-530 — compact downloaded indicator. The gallery card's
                        // full "Downloaded" capsule (``RecipeCard/downloadedBadge``)
                        // doesn't fit the dense row, so a small accent glyph beside
                        // the title carries the same status; only the Saved tab
                        // passes `isDownloaded: true` (Feed/Search default `false`,
                        // so their baselines are unchanged).
                        if isDownloaded {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(DODColor.accent)
                                .accessibilityLabel("Downloaded")
                        }
                    }
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
            .frame(width: thumbnailSize, height: thumbnailSize)
            .clipShape(RoundedRectangle(cornerRadius: DODRadius.inner, style: .continuous))
            .accessibilityHidden(true)
        }
    }
}

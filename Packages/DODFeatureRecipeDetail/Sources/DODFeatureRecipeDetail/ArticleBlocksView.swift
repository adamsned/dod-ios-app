import DODDesignSystem
import DODSupport
import SwiftUI

/// Shared native-block renderer for a parsed ``ArticleBlock`` sequence.
///
/// Extracted from ``ArticleDetailView``'s private `blockView(_:)` /
/// `articleImage(_:caption:)` helpers (T-732 / CL-129) so the two surfaces
/// that render rich `ArticleBlock` content — articles (US-37 / AC-37.3, the
/// original consumer) and the new recipe-detail expanded blurb (AC-4.12 /
/// CL-129) — share a single source of truth for paragraph / heading / image /
/// list styling. Spencer's "articles look great now" feedback is preserved
/// byte-for-byte by this extraction (same fonts, colors, spacing, alignment,
/// textSelection treatment); the recipe-blurb expansion inherits the same
/// styling rather than re-deriving it.
///
/// Block rendering rules (preserved verbatim from the pre-T-732 private
/// helper):
/// - `.heading(level, text)` — `DODType.displayMedium` for `level ≤ 2`,
///   `DODType.heading` otherwise; `DODColor.label`; top padding `DODSpacing.sm`.
/// - `.paragraph(text)` — `DODType.body`; `DODColor.label`; `.textSelection(.enabled)`.
/// - `.image(url, caption)` — full-width `ReliableImage` (success → photo,
///   else a neutral placeholder), capped at `imageMaxHeight`, optional caption below
///   in `DODType.caption` + `DODColor.labelSecondary`.
/// - `.list(ordered, items)` — `VStack` of `HStack(.firstTextBaseline)` rows
///   with `•` (unordered) or `"\(index + 1)."` (ordered) leaders.
///
/// Carries `.tint(DODColor.accent)` so inline link runs in `AttributedString`
/// paragraphs / headings / list items render in the brand orange.
///
/// Spec trace: US-37 / AC-37.3 (article rendering, original consumer);
/// AC-4.12 / CL-129 (recipe-blurb expansion, T-732 consumer).
public struct ArticleBlocksView: View {

    public let blocks: [ArticleBlock]

    public init(blocks: [ArticleBlock]) {
        self.blocks = blocks
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DODSpacing.md) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .tint(DODColor.accent)
    }

    /// Render one parsed ``ArticleBlock`` as a native view. Extracted verbatim
    /// from the pre-T-732 private `ArticleDetailView.blockView(_:)` so the
    /// per-block styling is byte-identical to the article render Spencer
    /// approved.
    @ViewBuilder
    private func blockView(_ block: ArticleBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(text)
                .dodFont(level <= 2 ? DODType.displayMedium : DODType.heading)
                .foregroundStyle(DODColor.label)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, DODSpacing.sm)
                .accessibilityAddTraits(.isHeader)

        case .paragraph(let text):
            Text(text)
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.label)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)

        case .image(let url, let caption):
            articleImage(url: url, caption: caption)

        case .list(let ordered, let items):
            VStack(alignment: .leading, spacing: DODSpacing.sm) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: DODSpacing.sm) {
                        Text(ordered ? "\(index + 1)." : "•")
                            .dodFont(DODType.body)
                            .foregroundStyle(DODColor.labelSecondary)
                            .accessibilityHidden(!ordered)
                        Text(item)
                            .dodFont(DODType.body)
                            .foregroundStyle(DODColor.label)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    /// A full-width article photo with an optional caption. Extracted verbatim
    /// from the pre-T-732 private `ArticleDetailView.articleImage(url:caption:)`
    /// helper. Mirrors `RecipeDetailHero`'s `ReliableImage` phase handling; an
    /// unloaded/failed image shows a neutral placeholder rather than collapsing
    /// the layout.
    private func articleImage(url: URL, caption: String?) -> some View {
        VStack(alignment: .leading, spacing: DODSpacing.xs) {
            // T-839 — reliable cached loader (DUT-195's ReliableImage) instead of
            // AsyncImage, which left inline article photos stuck on the neutral
            // placeholder on a transient/cancelled load (tester-reported: the
            // "Fall and Winter Dump Cakes" article images came up blank).
            ReliableImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                default:
                    placeholder
                }
            }
            // Cap height so a tall vertical infographic / Pinterest pin
            // (e.g. 1200×4000) can't render many screens tall; scaledToFit
            // keeps the aspect ratio within the bound. (review DOD-ART-1)
            .frame(maxWidth: .infinity, maxHeight: Self.imageMaxHeight)
            .clipShape(RoundedRectangle(cornerRadius: DODRadius.standard))
            .accessibilityLabel(caption ?? "Article image")

            if let caption, !caption.isEmpty {
                Text(caption)
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: DODRadius.standard)
            .fill(DODColor.surfaceElevated)
            .aspectRatio(3.0 / 2.0, contentMode: .fit)
            .frame(maxWidth: .infinity)
    }

    /// Max on-screen height for an inline article photo (review DOD-ART-1).
    private static let imageMaxHeight: CGFloat = 480
}

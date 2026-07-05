import DODDesignSystem
import DODSupport
import SwiftUI

/// DUT-572 / CL-312 — recipe-detail full-description ("blurb") rendering.
///
/// The pre-DUT-572 surface capped the blurb at two paragraphs behind a
/// More/Less toggle (T-732 / T-733 / T-734 / T-735 / CL-129..132). The
/// redesign shows the **whole editorial write-up with inline images**, so this
/// extension now renders `viewModel.blurbBlocks` DIRECTLY through the shared
/// ``ArticleBlocksView`` (which already renders `.image` blocks via
/// `ReliableImage`). The More/Less branch, the `isBlurbExpanded` state, the
/// `.image` filter, and the `textOnlyBlurbBlocks` / `collapsedBlurbBlocks` /
/// `appendingEllipsisTail` helpers are all removed.
///
/// The empty-`blurbBlocks` fallback (the cached path where the source HTML
/// wasn't fetched fresh) still renders the stripped WordPress excerpt.
///
/// Spec trace: AC-4.12 (amended by CL-312), DUT-572.
extension RecipeDetailView {

    /// The full recipe description. Renders the parsed `viewModel.blurbBlocks`
    /// (paragraphs, headings, lists, AND inline images) via the shared
    /// ``ArticleBlocksView``. When `blurbBlocks` is empty (cached-recipe path),
    /// falls back to the list-item excerpt with the WordPress truncation tail
    /// stripped.
    @ViewBuilder
    var excerptText: some View {
        let strippedExcerpt = Self.strippingExcerptTruncationTail(
            from: viewModel.listItem.excerpt
        )
        if !viewModel.blurbBlocks.isEmpty {
            ArticleBlocksView(blocks: viewModel.blurbBlocks)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DODSpacing.md)
        } else if !strippedExcerpt.isEmpty {
            // Empty-`blurbBlocks` fallback (cached path). Render the WP excerpt
            // with `.label` so it matches the article visual register.
            Text(strippedExcerpt)
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.label)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DODSpacing.md)
        }
    }

    /// Strip the WordPress `the_excerpt()` server-side truncation tail from
    /// the displayed excerpt fallback. Handles `[…]` (Unicode U+2026 ellipsis),
    /// `[...]` (ASCII triple-dot), `[ … ]` / `[ ... ]` (with surrounding
    /// whitespace inside the brackets), and bare trailing `…` / `...` (when WP
    /// omits the brackets). Idempotent — running on already-stripped text is a
    /// no-op. Pure function for L1 test coverage; exposed `static` for test
    /// access via `@testable import`.
    static func strippingExcerptTruncationTail(from excerpt: String) -> String {
        var trimmed = excerpt.trimmingCharacters(in: .whitespacesAndNewlines)
        // Repeatedly strip recognized truncation tails; idempotent — exits
        // when no recognized tail remains. Order matters: try the bracketed
        // forms first (more specific) before the bare ellipsis (more general).
        var didChange = true
        while didChange {
            didChange = false
            for tail in Self.recognizedTruncationTails where trimmed.hasSuffix(tail) {
                trimmed.removeLast(tail.count)
                trimmed = trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
                didChange = true
                break
            }
        }
        return trimmed
    }

    /// Trailing-tail variants the excerpt-strip helper recognizes. Listed
    /// most-specific-first; the helper exits when no tail matches.
    fileprivate static let recognizedTruncationTails: [String] = [
        "[\u{2026}]",  // [Unicode ellipsis]
        "[...]",  // [ASCII triple-dot]
        "[ \u{2026} ]",  // padded Unicode bracket
        "[ ... ]",  // padded ASCII bracket
        "\u{2026}",  // bare Unicode ellipsis
        "...",  // bare ASCII triple-dot
    ]
}

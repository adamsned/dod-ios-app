import DODDesignSystem
import SwiftUI

/// T-732 / CL-129 / AC-4.12: recipe-detail blurb expand/collapse helpers.
///
/// Extracted from ``RecipeDetailView`` so the main file stays under
/// SwiftLint's file-length cap. The `excerptText` body + the
/// `strippingExcerptTruncationTail(from:)` pure helper + the
/// `recognizedTruncationTails` table all live here. The expanded blurb's
/// rich-block rendering goes through the shared ``ArticleBlocksView`` (in
/// `ArticleBlocksView.swift`) so articles and recipes use the same per-block
/// styling.
///
/// Spec trace: AC-4.12, CL-129, REG-33.
extension RecipeDetailView {

    /// T-732 / CL-129 / AC-4.12: collapse-by-default + tappable "More" →
    /// rich-block-expanded blurb + "Less" → collapse contract on the recipe
    /// description.
    ///
    /// **Collapsed (`isBlurbExpanded == false`, default):** renders the
    /// list-item `excerpt` with the WordPress `the_excerpt()` server-side
    /// `[…]` / `[...]` truncation tail stripped via
    /// ``strippingExcerptTruncationTail(from:)``, followed by an inline
    /// "More" affordance (`.dodFont(DODType.caption)` +
    /// `.foregroundStyle(DODColor.accent)`) when the view model has parsed
    /// `blurbBlocks` to expand into. The "More" button visually replaces the
    /// stripped "[…]" tail.
    ///
    /// **Expanded (`isBlurbExpanded == true`):** renders the parsed
    /// `viewModel.blurbBlocks` via the shared ``ArticleBlocksView`` (same
    /// per-block styling articles use per AC-37.3 — Spencer's "articles look
    /// great now" feedback preserved), followed by an inline "Less"
    /// affordance with identical styling.
    ///
    /// **No rich content (`blurbBlocks.isEmpty`):** renders only the stripped
    /// excerpt — no "More" button is offered. This is the cached-recipe path
    /// where the source HTML wasn't fetched fresh; the next online open
    /// repopulates `blurbBlocks` via the fetch path.
    @ViewBuilder
    var excerptText: some View {
        let strippedExcerpt = Self.strippingExcerptTruncationTail(
            from: viewModel.listItem.excerpt
        )
        if !strippedExcerpt.isEmpty || (!viewModel.blurbBlocks.isEmpty && isBlurbExpanded) {
            VStack(alignment: .leading, spacing: DODSpacing.sm) {
                if isBlurbExpanded, !viewModel.blurbBlocks.isEmpty {
                    ArticleBlocksView(blocks: viewModel.blurbBlocks)
                    Button {
                        withAnimation { isBlurbExpanded = false }
                    } label: {
                        Text("Less")
                            .dodFont(DODType.caption)
                            .foregroundStyle(DODColor.accent)
                    }
                    .accessibilityLabel("Show less of the recipe description")
                } else {
                    if !strippedExcerpt.isEmpty {
                        Text(strippedExcerpt)
                            .dodFont(DODType.body)
                            .foregroundStyle(DODColor.labelSecondary)
                    }
                    if !viewModel.blurbBlocks.isEmpty {
                        Button {
                            withAnimation { isBlurbExpanded = true }
                        } label: {
                            Text("More")
                                .dodFont(DODType.caption)
                                .foregroundStyle(DODColor.accent)
                        }
                        .accessibilityLabel("Show more of the recipe description")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DODSpacing.md)
        }
    }

    /// Strip the WordPress `the_excerpt()` server-side truncation tail from
    /// the displayed excerpt so the "More" button visually replaces it.
    /// Handles `[…]` (Unicode U+2026 ellipsis), `[...]` (ASCII triple-dot),
    /// `[ … ]` / `[ ... ]` (with surrounding whitespace inside the brackets),
    /// and bare trailing `…` / `...` (when WP omits the brackets). Idempotent
    /// — running on already-stripped text is a no-op. Pure function for L1
    /// test coverage; exposed `static` for test access via `@testable import`.
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

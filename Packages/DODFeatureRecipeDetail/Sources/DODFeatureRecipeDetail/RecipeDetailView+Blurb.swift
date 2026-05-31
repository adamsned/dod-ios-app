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

    /// T-732 / CL-129 / AC-4.12 (amended by T-733 / CL-130): collapse-by-
    /// default + tappable "More" → rich-block-expanded blurb + "Less" →
    /// collapse contract on the recipe description.
    ///
    /// **Collapsed (`isBlurbExpanded == false`, default):** renders the
    /// list-item `excerpt` with the WordPress `the_excerpt()` server-side
    /// `[…]` / `[...]` truncation tail stripped via
    /// ``strippingExcerptTruncationTail(from:)`` AND a literal `"..."` tail
    /// concatenated directly to the prose (T-733 / CL-130 — the app's own
    /// visible continuation cue, NOT the WP source's truncation marker; the
    /// WP source's tail is still stripped first, then "..." attached at
    /// display time so the visible result is consistent across the six
    /// WP-source variants the strip helper recognizes), followed by an
    /// inline "More" affordance (`.dodFont(DODType.caption)` +
    /// `.foregroundStyle(DODColor.accent)`) when the view model reports
    /// `hasExpandableBlurb == true` (T-733 / CL-130 broadened the gate from
    /// `!blurbBlocks.isEmpty` to "any `.paragraph` block in `blurbBlocks`"
    /// so a recipe whose pre-WPRM content is only a heading / image / list
    /// — no narrative paragraph — correctly gets no More button).
    ///
    /// **Expanded (`isBlurbExpanded == true`):** renders the parsed
    /// `viewModel.blurbBlocks` via the shared ``ArticleBlocksView`` (same
    /// per-block styling articles use per AC-37.3 — Spencer's "articles look
    /// great now" feedback preserved; capped to 1-2 additional paragraphs
    /// per T-733 / CL-130 via the extractor's `paragraphLimit`), followed by
    /// an inline "Less" affordance with identical styling. The `"..."` tail
    /// from the collapsed state is NOT rendered here — the rich blocks
    /// continue the prose so no ellipsis is needed.
    ///
    /// **No rich content (`hasExpandableBlurb == false`):** renders only the
    /// stripped excerpt with no `"..."` tail and no "More" button — there's
    /// nothing to expand into. This is the cached-recipe path where the
    /// source HTML wasn't fetched fresh OR a recipe whose pre-WPRM content
    /// is only a heading / image / list; the next online open repopulates
    /// `blurbBlocks` via the fetch path.
    @ViewBuilder
    var excerptText: some View {
        let strippedExcerpt = Self.strippingExcerptTruncationTail(
            from: viewModel.listItem.excerpt
        )
        if !strippedExcerpt.isEmpty || (viewModel.hasExpandableBlurb && isBlurbExpanded) {
            VStack(alignment: .leading, spacing: DODSpacing.sm) {
                if isBlurbExpanded, viewModel.hasExpandableBlurb {
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
                        // T-733 / CL-130: append a literal "..." tail to the
                        // displayed excerpt only when there's something to
                        // expand into (hasExpandableBlurb). When the gate is
                        // false there's no More button, and the "..." would
                        // be a dangling cue with no follow-through — so omit
                        // it. The "..." is view-only — NEVER appended to the
                        // model's excerpt, NEVER stored, NEVER rendered in
                        // the expanded state.
                        Text(viewModel.hasExpandableBlurb ? strippedExcerpt + "..." : strippedExcerpt)
                            .dodFont(DODType.body)
                            .foregroundStyle(DODColor.labelSecondary)
                    }
                    if viewModel.hasExpandableBlurb {
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

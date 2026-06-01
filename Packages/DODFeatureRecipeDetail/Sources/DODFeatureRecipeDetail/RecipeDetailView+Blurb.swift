import DODDesignSystem
import DODSupport
import SwiftUI

/// T-732 / CL-129 / AC-4.12: recipe-detail blurb expand/collapse helpers.
///
/// Extracted from ``RecipeDetailView`` so the main file stays under
/// SwiftLint's file-length cap. The `excerptText` body + the
/// `strippingExcerptTruncationTail(from:)` pure helper + the
/// `recognizedTruncationTails` table all live here. Both the collapsed
/// (T-734 / CL-131) and expanded (T-732 / CL-129) blurb states render
/// through the shared ``ArticleBlocksView`` (in `ArticleBlocksView.swift`)
/// so articles, the collapsed recipe-blurb, and the expanded recipe-blurb
/// all use the same per-block styling — same color, font, bold / italic,
/// and link treatment.
///
/// Spec trace: AC-4.12, CL-129, CL-130, CL-131, REG-33.
extension RecipeDetailView {

    /// T-732 / CL-129 / AC-4.12 (amended by T-733 / CL-130 and T-734 /
    /// CL-131): collapse-by-default + tappable "More" → rich-block-expanded
    /// blurb + "Less" → collapse contract on the recipe description.
    ///
    /// **Collapsed (`isBlurbExpanded == false`, default) with rich blocks
    /// (`hasExpandableBlurb == true`):** renders the first paragraph block
    /// from `viewModel.blurbBlocks` via the shared ``ArticleBlocksView``
    /// (T-734 / CL-131 — same view, same per-block styling, same
    /// `DODColor.label` foreground, same inline bold / italic / link
    /// treatment as the expanded surface; pre-T-734 this branch rendered
    /// plain `Text(strippedExcerpt + "...")` with `.labelSecondary`, which
    /// drifted visually from the expanded `ArticleBlocksView` render). The
    /// literal `"..."` tail (T-733 / CL-130 — the app's own visible
    /// continuation cue, NEVER from the WP source) attaches inline to the
    /// first paragraph's `AttributedString` via
    /// ``appendingEllipsisTail(to:)`` which preserves the paragraph's inline
    /// bold / italic / link attribute runs and appends a plain `"..."` run
    /// at the end. The "More" affordance (`.dodFont(DODType.caption)` +
    /// `.foregroundStyle(DODColor.accent)`) sits below the rendered
    /// paragraph as a separate row (kept out of the inline prose so the
    /// tap target stays clean).
    ///
    /// **Collapsed (`isBlurbExpanded == false`) with no rich blocks
    /// (`hasExpandableBlurb == false`):** falls back to rendering the
    /// list-item `excerpt` with the WordPress `the_excerpt()` server-side
    /// `[…]` / `[...]` truncation tail stripped via
    /// ``strippingExcerptTruncationTail(from:)``, using
    /// `.foregroundStyle(DODColor.label)` (T-734 / CL-131 — not
    /// `.labelSecondary`, so even the fallback path matches the article
    /// visual register). No `"..."` tail and no "More" button — there's
    /// nothing to expand into. This is the cached-recipe path where the
    /// source HTML wasn't fetched fresh OR a recipe whose pre-WPRM content
    /// is only a heading / image / list (T-733 / CL-130 broadened the gate
    /// from `!blurbBlocks.isEmpty` to "any `.paragraph` block in
    /// `blurbBlocks`" so this fallback fires whenever no narrative
    /// paragraph is available); the next online open repopulates
    /// `blurbBlocks` via the fetch path.
    ///
    /// **Expanded (`isBlurbExpanded == true`):** renders the parsed
    /// `viewModel.blurbBlocks` via the shared ``ArticleBlocksView`` (same
    /// per-block styling articles use per AC-37.3; capped to 1-2 additional
    /// paragraphs per T-733 / CL-130 via the extractor's `paragraphLimit`),
    /// followed by a "Less" affordance with the same caption + accent
    /// styling. The `"..."` tail from the collapsed state is NOT rendered
    /// here — the rich blocks continue the prose so no ellipsis is needed.
    @ViewBuilder
    var excerptText: some View {
        let strippedExcerpt = Self.strippingExcerptTruncationTail(
            from: viewModel.listItem.excerpt
        )
        // T-735 / CL-132: filter `.image` blocks out of the blurb-rendering
        // path. The collapsed render, the expanded render, AND the More-
        // button visibility gate all consume `textOnlyBlocks` — a blurb
        // whose ONLY content is images correctly hides the More button
        // (nothing text-y to expand into). Live-API audit on 2026-05-31
        // found 3 of 11 production recipes carry image-first block
        // sequences (?p=274, 5016, 524) — pre-T-735 the collapsed surface
        // rendered an opaque Pinterest-preview photo where the user
        // expected the first text paragraph. The view-model's blurbBlocks
        // remains structurally faithful for any future consumer; the
        // filter is a view-side concern. ArticleDetailView is NOT touched
        // and continues to render images per AC-37.3.
        let textOnlyBlocks = Self.textOnlyBlurbBlocks(from: viewModel.blurbBlocks)
        let hasExpandableTextBlurb = textOnlyBlocks.contains { block in
            if case .paragraph = block { return true }
            return false
        }
        let collapsedBlocks = Self.collapsedBlurbBlocks(from: textOnlyBlocks)
        let canRenderCollapsedRich = !collapsedBlocks.isEmpty
        let shouldRender =
            !strippedExcerpt.isEmpty || canRenderCollapsedRich
            || (hasExpandableTextBlurb && isBlurbExpanded)
        if shouldRender {
            VStack(alignment: .leading, spacing: DODSpacing.sm) {
                if isBlurbExpanded, hasExpandableTextBlurb {
                    ArticleBlocksView(blocks: textOnlyBlocks)
                    Button {
                        withAnimation { isBlurbExpanded = false }
                    } label: {
                        Text("Less")
                            .dodFont(DODType.caption)
                            .foregroundStyle(DODColor.accent)
                    }
                    .accessibilityLabel("Show less of the recipe description")
                } else if canRenderCollapsedRich {
                    // T-734 / CL-131: render the collapsed surface via the
                    // same ArticleBlocksView the expanded surface uses, so
                    // typography / color / bold / italic / link styling
                    // agree byte-identically across the two states. The
                    // "..." tail attaches inline to the first paragraph's
                    // AttributedString via appendingEllipsisTail — view-
                    // only, NEVER stored, NEVER rendered in the expanded
                    // state.
                    ArticleBlocksView(blocks: collapsedBlocks)
                    if hasExpandableTextBlurb {
                        Button {
                            withAnimation { isBlurbExpanded = true }
                        } label: {
                            Text("More")
                                .dodFont(DODType.caption)
                                .foregroundStyle(DODColor.accent)
                        }
                        .accessibilityLabel("Show more of the recipe description")
                    }
                } else if !strippedExcerpt.isEmpty {
                    // T-734 / CL-131: empty-`blurbBlocks` fallback. Render
                    // the WP excerpt with `.label` (NOT `.labelSecondary`)
                    // so even the fallback path matches the article-
                    // rendering visual register. No "..." tail and no
                    // "More" button — nothing to expand into per the
                    // T-733 / CL-130 `hasExpandableBlurb` gate.
                    Text(strippedExcerpt)
                        .dodFont(DODType.body)
                        .foregroundStyle(DODColor.label)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DODSpacing.md)
        }
    }

    /// T-735 / CL-132: filter `.image` blocks out of a `[ArticleBlock]`
    /// sequence for the blurb-rendering path. The view-model's
    /// `blurbBlocks` stays structurally faithful (still includes images
    /// for any future consumer); the filter is view-side. `ArticleDetailView`
    /// does NOT use this helper — articles still render images per AC-37.3.
    ///
    /// Admits `.paragraph` / `.heading` / `.list` and drops `.image`. The
    /// switch is exhaustive (compiler-checked) so future `ArticleBlock`
    /// cases force an explicit decision at this call site. Pure function;
    /// static for L1 test access via `@testable import`.
    static func textOnlyBlurbBlocks(from blocks: [ArticleBlock]) -> [ArticleBlock] {
        var result: [ArticleBlock] = []
        result.reserveCapacity(blocks.count)
        for block in blocks {
            if case .image = block { continue }
            result.append(block)
        }
        return result
    }

    /// T-734 / CL-131: returns the blocks the collapsed surface should
    /// render via ``ArticleBlocksView``. Takes the first block of the input
    /// (which is the first paragraph per the `hasExpandableBlurb` gate's
    /// `.paragraph`-presence guarantee — when that gate is true, the first
    /// `.paragraph` is always near the front; pre-paragraph headings /
    /// images / lists from the parser are bounded to typical
    /// `entry-content` HTML shapes), appends a literal `"..."` tail to its
    /// `AttributedString` (preserving inline bold / italic / link attribute
    /// runs for the prose before the appended text), and returns
    /// `[firstBlockWithEllipsis]`. Returns `[]` for empty input. Static for
    /// L1 test access via `@testable import`.
    static func collapsedBlurbBlocks(from blocks: [ArticleBlock]) -> [ArticleBlock] {
        guard let first = blocks.first else { return [] }
        return [appendingEllipsisTail(to: first)]
    }

    /// T-734 / CL-131: appends a literal `"..."` tail to a `.paragraph`
    /// block's `AttributedString`. The append preserves the source string's
    /// inline attribute runs (bold / italic / link spans that ended before
    /// the end of the paragraph remain attributed); the appended `"..."`
    /// carries no attributes (plain run, inherits the paragraph's base
    /// styling). Non-`.paragraph` blocks pass through unchanged. Pure
    /// function; static for L1 test access via `@testable import`.
    static func appendingEllipsisTail(to block: ArticleBlock) -> ArticleBlock {
        guard case .paragraph(var text) = block else { return block }
        text.append(AttributedString("..."))
        return .paragraph(text)
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

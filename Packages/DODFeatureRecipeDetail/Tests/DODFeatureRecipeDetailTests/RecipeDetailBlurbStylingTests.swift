import DODSupport
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// L1 coverage for the T-734 / CL-131 blurb-styling-unify helpers on
/// ``RecipeDetailView`` — `appendingEllipsisTail(to:)` and
/// `collapsedBlurbBlocks(from:)`. These are pure functions; the helpers
/// guarantee the collapsed surface renders the first paragraph block via
/// the same ``ArticleBlocksView`` the expanded surface uses, with the
/// `"..."` tail attached inline to the `AttributedString` so the inline
/// bold / italic / link attribute runs are preserved.
///
/// Spec trace: AC-4.12 (amended), CL-131, REG-33.
@Suite("RecipeDetailView blurb-styling helpers (T-734 / CL-131)")
struct RecipeDetailBlurbStylingTests {

    // MARK: - appendingEllipsisTail(to:)

    /// A `.paragraph` block with no inline attribute runs gets the
    /// `"..."` tail concatenated to its `AttributedString`. The output is
    /// still a `.paragraph` (same case) and the underlying characters end
    /// in the literal three-ASCII-dot tail.
    @Test func appendingEllipsisTailToPlainParagraph() {
        let input = ArticleBlock.paragraph(AttributedString("foo bar"))

        let output = RecipeDetailView.appendingEllipsisTail(to: input)

        guard case .paragraph(let attributed) = output else {
            Issue.record("expected .paragraph output, got \(output)")
            return
        }
        #expect(String(attributed.characters) == "foo bar...")
    }

    /// A `.paragraph` whose `AttributedString` carries a bold inline run
    /// mid-string keeps the bold run intact after the tail append; the
    /// appended `"..."` carries no attributes (plain run, inherits the
    /// paragraph's base styling). Verified by walking the output's
    /// attribute runs and asserting the bold span lives at the same
    /// substring as the input.
    @Test func appendingEllipsisTailPreservesBoldRun() {
        var attributed = AttributedString("foo ")
        var bold = AttributedString("bar")
        bold.inlinePresentationIntent = .stronglyEmphasized
        attributed.append(bold)
        attributed.append(AttributedString(" baz"))
        let input = ArticleBlock.paragraph(attributed)

        let output = RecipeDetailView.appendingEllipsisTail(to: input)

        guard case .paragraph(let outAttributed) = output else {
            Issue.record("expected .paragraph output, got \(output)")
            return
        }
        #expect(String(outAttributed.characters) == "foo bar baz...")
        // The bold run on "bar" survives the append. Walk the runs and
        // assert exactly one run is stronglyEmphasized and its characters
        // are "bar".
        let boldRuns = outAttributed.runs.filter { run in
            run.inlinePresentationIntent == .stronglyEmphasized
        }
        #expect(boldRuns.count == 1)
        if let boldRun = boldRuns.first {
            #expect(String(outAttributed[boldRun.range].characters) == "bar")
        }
    }

    /// Non-`.paragraph` blocks (heading / image / list) pass through
    /// unchanged — `appendingEllipsisTail(to:)` is a no-op for cases other
    /// than `.paragraph`. The `hasExpandableBlurb` gate guarantees the
    /// first paragraph is reachable at the call site; this guard prevents
    /// silent text injection into non-text blocks if a future caller
    /// passes a heading by mistake.
    @Test func appendingEllipsisTailNoOpForHeading() throws {
        let input = ArticleBlock.heading(level: 2, text: AttributedString("A heading"))

        let output = RecipeDetailView.appendingEllipsisTail(to: input)

        guard case .heading(let level, let text) = output else {
            Issue.record("expected .heading output, got \(output)")
            return
        }
        #expect(level == 2)
        #expect(String(text.characters) == "A heading")
    }

    // MARK: - collapsedBlurbBlocks(from:)

    /// Empty input returns empty output — the empty-`blurbBlocks` path
    /// where the view falls back to the WP-excerpt-as-`Text` render.
    @Test func collapsedBlurbBlocksEmptyInputReturnsEmpty() {
        let output = RecipeDetailView.collapsedBlurbBlocks(from: [])
        #expect(output.isEmpty)
    }

    /// Single-paragraph input returns a single-block output with the
    /// `"..."` tail attached.
    @Test func collapsedBlurbBlocksSingleParagraphReturnsOneBlockWithTail() {
        let input: [ArticleBlock] = [
            .paragraph(AttributedString("first para"))
        ]

        let output = RecipeDetailView.collapsedBlurbBlocks(from: input)

        #expect(output.count == 1)
        guard case .paragraph(let attributed) = output[0] else {
            Issue.record("expected .paragraph at index 0, got \(output[0])")
            return
        }
        #expect(String(attributed.characters) == "first para...")
    }

    /// Multi-paragraph input returns ONLY the first block (with the tail)
    /// — the collapsed surface shows paragraph 1 only; paragraphs 2+ are
    /// the expanded-surface content. The "..." is the visible cue that
    /// more content lies behind the "More" button.
    @Test func collapsedBlurbBlocksMultipleParagraphsReturnsOnlyFirst() {
        let input: [ArticleBlock] = [
            .paragraph(AttributedString("first para")),
            .paragraph(AttributedString("second para")),
            .paragraph(AttributedString("third para")),
        ]

        let output = RecipeDetailView.collapsedBlurbBlocks(from: input)

        #expect(output.count == 1)
        guard case .paragraph(let attributed) = output[0] else {
            Issue.record("expected .paragraph at index 0, got \(output[0])")
            return
        }
        #expect(String(attributed.characters) == "first para...")
    }

    /// When the first block is a non-`.paragraph` (heading), the helper
    /// still returns one block (the first one, unchanged). This is a
    /// defensive shape — in practice `hasExpandableBlurb` gates the
    /// collapsed-rich branch, so the caller only reaches this path when
    /// at least one `.paragraph` exists. Still, the first-block-as-unit
    /// invariant should not silently re-order the array.
    @Test func collapsedBlurbBlocksFirstBlockIsHeadingPassesThroughUnchanged() {
        let input: [ArticleBlock] = [
            .heading(level: 2, text: AttributedString("A heading")),
            .paragraph(AttributedString("a para")),
        ]

        let output = RecipeDetailView.collapsedBlurbBlocks(from: input)

        #expect(output.count == 1)
        guard case .heading(let level, let text) = output[0] else {
            Issue.record("expected .heading at index 0, got \(output[0])")
            return
        }
        #expect(level == 2)
        #expect(String(text.characters) == "A heading")
    }

    // MARK: - textOnlyBlurbBlocks(from:) — T-735 / CL-132

    /// Empty input returns empty output — degenerate-but-safe.
    @Test func textOnlyBlurbBlocksEmptyInputReturnsEmpty() {
        let output = RecipeDetailView.textOnlyBlurbBlocks(from: [])
        #expect(output.isEmpty)
    }

    /// Mixed `[paragraph, image, paragraph]` input returns the two
    /// paragraphs only — the image is dropped. The order of the
    /// surviving blocks is preserved (stable filter).
    @Test func textOnlyBlurbBlocksDropsImageBlocks() throws {
        let imageURL = try #require(URL(string: "https://example.com/x.png"))
        let input: [ArticleBlock] = [
            .paragraph(AttributedString("first para")),
            .image(url: imageURL, caption: nil),
            .paragraph(AttributedString("second para")),
        ]

        let output = RecipeDetailView.textOnlyBlurbBlocks(from: input)

        #expect(output.count == 2)
        let containsImage = output.contains { block in
            if case .image = block { return true }
            return false
        }
        #expect(!containsImage)
    }

    /// Image-only input returns empty — the blurb-rendering path sees
    /// no text to show, so the More button must not appear.
    @Test func textOnlyBlurbBlocksImageOnlyInputReturnsEmpty() throws {
        let imageURL = try #require(URL(string: "https://example.com/x.png"))
        let input: [ArticleBlock] = [
            .image(url: imageURL, caption: "alt text"),
            .image(url: imageURL, caption: nil),
        ]

        let output = RecipeDetailView.textOnlyBlurbBlocks(from: input)

        #expect(output.isEmpty)
    }

    /// `.heading` and `.list` blocks pass through — only `.image` is
    /// dropped. Mirrors the live-API case where intro narrative
    /// paragraphs may be interleaved with section headings or bullet
    /// lists before the recipe card (recipe ?p=524 in the 2026-05-31
    /// audit returns a `.list` block between paragraphs).
    @Test func textOnlyBlurbBlocksPreservesHeadingsAndLists() {
        let input: [ArticleBlock] = [
            .heading(level: 2, text: AttributedString("A heading")),
            .list(ordered: false, items: [AttributedString("item")]),
            .paragraph(AttributedString("a para")),
        ]

        let output = RecipeDetailView.textOnlyBlurbBlocks(from: input)

        #expect(output.count == 3)
    }

    /// Image-first sequence — the most common live-API shape on
    /// `dutchovendaddy.com` recipes that embed Pinterest social-preview
    /// images at the top of the entry-content. After filtering, the
    /// first surviving block is a `.paragraph` and
    /// `collapsedBlurbBlocks(from:)` correctly attaches the `"..."` tail
    /// to it (regression test for the pre-T-735 bug where the collapsed
    /// surface rendered an opaque image instead of the first paragraph).
    @Test func textOnlyBlurbBlocksImageFirstSequenceProducesParagraphFirst() throws {
        let imageURL = try #require(URL(string: "https://example.com/pinterest.png"))
        let input: [ArticleBlock] = [
            .image(url: imageURL, caption: "Pinterest preview"),
            .image(url: imageURL, caption: "another preview"),
            .paragraph(AttributedString("the real first paragraph")),
            .paragraph(AttributedString("the second paragraph")),
        ]

        let filtered = RecipeDetailView.textOnlyBlurbBlocks(from: input)
        let collapsed = RecipeDetailView.collapsedBlurbBlocks(from: filtered)

        // After filtering, the first surviving block is the first
        // paragraph — collapsedBlurbBlocks attaches "..." to it.
        #expect(collapsed.count == 1)
        guard case .paragraph(let attributed) = collapsed[0] else {
            Issue.record("expected .paragraph in collapsed[0], got \(collapsed[0])")
            return
        }
        #expect(String(attributed.characters) == "the real first paragraph...")
    }
}

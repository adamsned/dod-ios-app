import Testing

@testable import DODFeatureRecipeDetail

/// L1 unit coverage for `RecipeDetailView.strippingExcerptTruncationTail(from:)`
/// — the pure helper that removes the WordPress `the_excerpt()` server-side
/// truncation tail (`[…]` / `[...]` / bare ellipsis) from the displayed excerpt
/// so the "More" affordance visually replaces it (T-732 / CL-129 / AC-4.12).
///
/// Spec trace: AC-4.12, CL-129, REG-33.
@MainActor
@Suite("RecipeDetailView.strippingExcerptTruncationTail (T-732 / CL-129)")
struct RecipeDetailExcerptStripTests {

    @Test func stripsBracketedASCIIEllipsisTail() {
        let result = RecipeDetailView.strippingExcerptTruncationTail(from: "blurb text [...]")
        #expect(result == "blurb text")
    }

    @Test func stripsBracketedUnicodeEllipsisTail() {
        let result = RecipeDetailView.strippingExcerptTruncationTail(from: "blurb text [\u{2026}]")
        #expect(result == "blurb text")
    }

    @Test func stripsPaddedBracketedTail() {
        // WordPress sometimes emits `[ ... ]` with internal whitespace.
        let result = RecipeDetailView.strippingExcerptTruncationTail(
            from: "blurb text [ ... ]"
        )
        #expect(result == "blurb text")
    }

    @Test func stripsPaddedBracketedUnicodeTail() {
        let result = RecipeDetailView.strippingExcerptTruncationTail(
            from: "blurb text [ \u{2026} ]"
        )
        #expect(result == "blurb text")
    }

    @Test func stripsBareUnicodeEllipsisTail() {
        let result = RecipeDetailView.strippingExcerptTruncationTail(
            from: "blurb text\u{2026}"
        )
        #expect(result == "blurb text")
    }

    @Test func stripsBareASCIITripleDotTail() {
        let result = RecipeDetailView.strippingExcerptTruncationTail(from: "blurb text...")
        #expect(result == "blurb text")
    }

    @Test func passesThroughTextWithoutTruncationTail() {
        // Idempotent — text that doesn't end with a recognized tail is
        // returned unchanged (modulo edge whitespace trimming).
        let result = RecipeDetailView.strippingExcerptTruncationTail(
            from: "blurb text"
        )
        #expect(result == "blurb text")
    }

    @Test func emptyStringPassesThrough() {
        let result = RecipeDetailView.strippingExcerptTruncationTail(from: "")
        #expect(result.isEmpty)
    }

    @Test func whitespaceOnlyStringPassesThroughAsEmpty() {
        // `trimmingCharacters` collapses pure whitespace to empty.
        let result = RecipeDetailView.strippingExcerptTruncationTail(from: "   ")
        #expect(result.isEmpty)
    }

    @Test func handlesTrailingWhitespaceBeforeTail() {
        // The helper trims trailing whitespace before scanning for tails.
        let result = RecipeDetailView.strippingExcerptTruncationTail(
            from: "blurb text  [...]"
        )
        #expect(result == "blurb text")
    }

    @Test func isIdempotentWhenRunTwice() {
        // Running the helper a second time on an already-stripped string is
        // a no-op — the steady state stays at the stripped form.
        let once = RecipeDetailView.strippingExcerptTruncationTail(
            from: "blurb text [...]"
        )
        let twice = RecipeDetailView.strippingExcerptTruncationTail(from: once)
        #expect(once == twice)
        #expect(twice == "blurb text")
    }

    @Test func stripsCascadedTails() {
        // Defensive: when WP layers a bare ellipsis followed by a bracketed
        // ellipsis (rare but observed in some legacy themes), strip both.
        let result = RecipeDetailView.strippingExcerptTruncationTail(
            from: "blurb text\u{2026} [...]"
        )
        #expect(result == "blurb text")
    }
}

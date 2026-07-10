import Testing

@testable import DODSupport

/// DUT-912 — recipes write quantity ranges with the WORDS "to"/"or" as often
/// as with a dash ("2 to 3 cloves", "3 or 4 cups"). DUT-304 only taught
/// `scaleRangeContinuation` the dash glyphs, so the word forms scaled only the
/// lower bound and left a backwards range ("2 to 3" ×2 → "4 to 3"). This locks
/// both bounds scaling for the word separators while pinning that the existing
/// dash handling (and the not-a-range guards) is unchanged.
@Suite("FractionRenderer word-range scaling (DUT-912)")
struct FractionRendererWordRangeTests {

    @Test func toWordRangeScalesBothBounds() {
        #expect(FractionRenderer.scale("2 to 3 cloves", by: 2) == "4 to 6 cloves")
    }

    @Test func toWordRangeScalesBothBoundsAtOtherFactors() {
        #expect(FractionRenderer.scale("1 to 2 tablespoons", by: 3) == "3 to 6 tablespoons")
    }

    @Test func orWordRangeScalesBothBounds() {
        #expect(FractionRenderer.scale("3 or 4 cups", by: 2) == "6 or 8 cups")
    }

    @Test func wordRangePreservesSpacingAndCase() {
        // The verbatim separator (incl. its spaces + original casing) is re-emitted.
        #expect(FractionRenderer.scale("2 TO 3 cloves", by: 2) == "4 TO 6 cloves")
    }

    @Test func wordRangeWithFractionBounds() {
        // "½ to 1 cup" ×3 → "1 ½ to 3 cup": both bounds run through the renderer.
        #expect(FractionRenderer.scale("1/2 to 1 cup", by: 3) == "1 ½ to 3 cup")
    }

    @Test func wordThatMerelyStartsWithARangeWordIsNotASeparator() {
        // "2 tomatoes" must NOT be read as "2 to matoes" — the word boundary
        // guard keeps a single quantity single. (No trailing high bound, so the
        // line just scales its one quantity.)
        #expect(FractionRenderer.scale("2 tomatoes", by: 2) == "4 tomatoes")
    }

    @Test func dashRangeStillScalesBothBounds() {
        // DUT-304 behavior is untouched.
        #expect(FractionRenderer.scale("2-3 cloves", by: 2) == "4-6 cloves")
    }

    @Test func spacedDashRangeStillPreservesItsSpacing() {
        #expect(FractionRenderer.scale("1 - 2 cups", by: 3) == "3 - 6 cups")
    }

    @Test func hyphenatedUnitStillGainsNoSpuriousRange() {
        // "1-inch piece" is not a range (no numeric upper bound) — unchanged.
        #expect(FractionRenderer.scale("1-inch piece", by: 2) == "2-inch piece")
    }
}

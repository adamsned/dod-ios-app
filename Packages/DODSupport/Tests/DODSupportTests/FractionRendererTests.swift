import Foundation
import Testing

@testable import DODSupport

/// Golden L1 coverage for ``FractionRenderer``.
///
/// Spec trace: US-31 / AC-31.4 + AC-31.5 (scaling math + fraction-rendering
/// precision), CL-52 (canonical fraction set + tolerance rationale).
/// Constitution §6 L1 mandate — every domain transform owns named tests.
@Suite("FractionRenderer") struct FractionRendererTests {

    // MARK: - Backlog quote: the load-bearing cases

    /// "½ × 1.5 → ¾, not 0.75" — the explicit backlog promise.
    @Test func vulgarHalfTimesOnePointFive() {
        #expect(FractionRenderer.scale("½ cup flour", by: 1.5) == "¾ cup flour")
    }

    /// "1 × 2 → 2, not 2.0" — integer quantities must drop the decimal.
    @Test func integerTimesTwo() {
        #expect(FractionRenderer.scale("1 tablespoon salt", by: 2.0) == "2 tablespoon salt")
    }

    /// "2 ½ × 2 → 5, not 5.0" — mixed numbers fold back to a clean integer.
    @Test func mixedTwoAndAHalfTimesTwo() {
        #expect(FractionRenderer.scale("2 ½ cups milk", by: 2.0) == "5 cups milk")
    }

    /// "1 ⅓ × 3 → 4, not 4.0" — the rational-floor case.
    @Test func mixedOneAndOneThirdTimesThree() {
        #expect(FractionRenderer.scale("1 ⅓ cups stock", by: 3.0) == "4 cups stock")
    }

    /// Decimal source quantities snap to a sensible fraction.
    /// `1.5 lbs × 2 → 3 lbs`.
    @Test func decimalSourceTimesTwo() {
        #expect(FractionRenderer.scale("1.5 lbs cod", by: 2.0) == "3 lbs cod")
    }

    // MARK: - Canonical fraction snap-set (CL-52)

    /// ASCII fraction "1/4" × 3 → "¾".
    @Test func asciiQuarterTimesThree() {
        #expect(FractionRenderer.scale("1/4 cup oil", by: 3.0) == "¾ cup oil")
    }

    /// "⅓ × 2 → ⅔" — small-fraction × small-int round-trip.
    @Test func vulgarThirdTimesTwo() {
        #expect(FractionRenderer.scale("⅓ cup honey", by: 2.0) == "⅔ cup honey")
    }

    /// "⅔ × 0.5 → ⅓" — halving brings two-thirds back to one-third.
    @Test func vulgarTwoThirdsTimesOneHalf() {
        #expect(FractionRenderer.scale("⅔ cup sugar", by: 0.5) == "⅓ cup sugar")
    }

    /// Mixed ASCII fraction "1 1/2" preserves through identity multiply
    /// (factor 1 returns text verbatim, no re-rendering).
    @Test func mixedAsciiFactorOneReturnsVerbatim() {
        #expect(
            FractionRenderer.scale("1 1/2 pounds cod fillets", by: 1.0)
                == "1 1/2 pounds cod fillets"
        )
    }

    /// Mixed ASCII fraction "1 1/2 × 2 → 3".
    @Test func mixedAsciiOneAndAHalfTimesTwo() {
        #expect(
            FractionRenderer.scale("1 1/2 pounds cod fillets", by: 2.0)
                == "3 pounds cod fillets"
        )
    }

    // MARK: - Quantity-less lines pass through

    /// No leading quantity → text returned verbatim. Salt-and-pepper lines
    /// must not gain a spurious "0" prefix.
    @Test func quantityLessLinePassesThrough() {
        let line = "Salt and freshly ground black pepper (to taste)"
        #expect(FractionRenderer.scale(line, by: 2.0) == line)
    }

    /// Lines that begin with a non-number word (no leading digit) pass through.
    @Test func nonNumericPrefixPassesThrough() {
        #expect(
            FractionRenderer.scale("melted butter (for dipping)", by: 2.0)
                == "melted butter (for dipping)"
        )
    }

    // MARK: - Edge cases

    /// Factor of 1.0 short-circuits and returns the input verbatim.
    @Test func factorOneShortCircuits() {
        #expect(FractionRenderer.scale("½ cup butter", by: 1.0) == "½ cup butter")
    }

    /// Zero or negative factors are invalid — return verbatim rather than
    /// emit `0 cups` for every ingredient.
    @Test func zeroFactorReturnsVerbatim() {
        #expect(FractionRenderer.scale("2 cups flour", by: 0.0) == "2 cups flour")
    }

    /// Three quarters × 4 → 3 (whole result, no fraction left over).
    @Test func threeQuartersTimesFour() {
        #expect(FractionRenderer.scale("¾ cup flour", by: 4.0) == "3 cup flour")
    }

    /// One eighth × 8 → 1.
    @Test func eighthTimesEight() {
        #expect(FractionRenderer.scale("⅛ tsp salt", by: 8.0) == "1 tsp salt")
    }

    /// Integer-only source × halving fraction = ½. "2 × 0.5 → 1".
    @Test func twoTimesOneHalf() {
        #expect(FractionRenderer.scale("2 cups flour", by: 0.5) == "1 cups flour")
    }

    /// Bigger scale: "¼ × 6 → 1 ½".
    @Test func quarterTimesSix() {
        #expect(FractionRenderer.scale("¼ cup vinegar", by: 6.0) == "1 ½ cup vinegar")
    }

    // MARK: - renderQuantity direct calls (lock the table)

    @Test func renderQuantityWholeOnly() {
        #expect(FractionRenderer.renderQuantity(4.0) == "4")
    }

    @Test func renderQuantityHalf() {
        #expect(FractionRenderer.renderQuantity(0.5) == "½")
    }

    @Test func renderQuantityOneAndAHalf() {
        #expect(FractionRenderer.renderQuantity(1.5) == "1 ½")
    }

    @Test func renderQuantityTwoThirds() {
        // 0.6667 lands within 0.0625 of 2/3.
        #expect(FractionRenderer.renderQuantity(2.0 / 3.0) == "⅔")
    }

    @Test func renderQuantityNearOneSnapsUp() {
        // 0.99 is within tolerance of 1.0 → bump to next whole.
        #expect(FractionRenderer.renderQuantity(0.99) == "1")
    }

    @Test func renderQuantitySnapsCloseDecimalToFraction() {
        // 0.34 is closest to 1/3 (0.333…) within tolerance.
        #expect(FractionRenderer.renderQuantity(0.34) == "⅓")
    }

    // MARK: - Warning threshold (AC-31.6)

    @Test func warningThresholdInclusiveAtTwelve() {
        #expect(FractionRenderer.shouldShowDutchOvenWarning(forServings: 12) == false)
    }

    @Test func warningThresholdActiveAtThirteen() {
        #expect(FractionRenderer.shouldShowDutchOvenWarning(forServings: 13) == true)
    }
}

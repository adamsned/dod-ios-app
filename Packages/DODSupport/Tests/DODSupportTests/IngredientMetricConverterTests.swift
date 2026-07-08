import Testing

@testable import DODSupport

/// L1 coverage for the imperial→metric ingredient converter (DUT-517 — the
/// ingredient half of the unit toggle, the deferred other half of DUT-47).
///
/// Every expectation pins a user-facing contract: a convertible imperial
/// measurement is rewritten to metric (grams / millilitres, rolling up to
/// kilograms / litres past 1000) with cooking-friendly rounding — nearest 5
/// below 100, nearest 10 at or above 100, and a one-decimal fallback for a tiny
/// measure that would otherwise round to a whole 0 (DUT-533) — while
/// already-metric units, count/descriptive units, and non-parseable lines pass
/// through byte for byte.
///
/// The converter runs on the ALREADY-SCALED line, so the composition tests
/// scale first (via ``FractionRenderer``) and then convert, matching the render
/// path in Recipe Detail + the Cook Mode drawer.
@Suite("IngredientMetricConverter (DUT-517 ingredient half)")
struct IngredientMetricConverterTests {

    // MARK: - Volume → millilitres

    @Test func cupToMilliliters() {
        // 1 × 240 = 240 ml → nearest 10 (>= 100) → 240 (no longer inflated to 250).
        #expect(IngredientMetricConverter.metric("1 cup flour") == "240 ml flour")
    }

    @Test func twoCupsToMilliliters() {
        // 2 × 240 = 480 ml → nearest 10 (>= 100) → 480.
        #expect(IngredientMetricConverter.metric("2 cups milk") == "480 ml milk")
    }

    @Test func tablespoonToMilliliters() {
        // 2 × 15 = 30 ml → nearest 5 (< 100) → 30.
        #expect(IngredientMetricConverter.metric("2 tablespoons olive oil") == "30 ml olive oil")
    }

    @Test func teaspoonToMilliliters() {
        // 1 × 5 = 5 ml → nearest 5 → 5.
        #expect(IngredientMetricConverter.metric("1 teaspoon salt") == "5 ml salt")
    }

    @Test func pintToMilliliters() {
        // 1 × 475 = 475 ml → nearest 10 (>= 100) → 480.
        #expect(IngredientMetricConverter.metric("1 pint cream") == "480 ml cream")
    }

    @Test func quartToMilliliters() {
        // 1 × 950 = 950 ml → nearest 25 → 950.
        #expect(IngredientMetricConverter.metric("1 quart stock") == "950 ml stock")
    }

    // MARK: - Mass → grams

    @Test func poundToGrams() {
        // 1 × 450 = 450 g → nearest 25 → 450.
        #expect(IngredientMetricConverter.metric("1 pound beef") == "450 g beef")
    }

    @Test func ounceToGrams() {
        // 4 × 28 = 112 g → nearest 10 (>= 100) → 112/10 = 11.2 → 11 → 110.
        #expect(IngredientMetricConverter.metric("4 ounces cheese") == "110 g cheese")
    }

    @Test func singleOunceRoundsToNearestFive() {
        // 1 × 28 = 28 g → nearest 5 (< 100) → 30.
        #expect(IngredientMetricConverter.metric("1 ounce chocolate") == "30 g chocolate")
    }

    // MARK: - Mixed / fraction quantities

    @Test func mixedNumberCups() {
        // "1 1/2 cups" → 1.5 × 240 = 360 ml → nearest 10 (>= 100) → 360.
        #expect(IngredientMetricConverter.metric("1 1/2 cups milk") == "360 ml milk")
    }

    @Test func vulgarFractionCup() {
        // "½ cup" → 0.5 × 240 = 120 ml → nearest 10 (>= 100) → 120.
        #expect(IngredientMetricConverter.metric("½ cup sugar") == "120 ml sugar")
    }

    // MARK: - Sub-half-teaspoon: never "0 ml" (DUT-533)

    @Test func quarterTeaspoonKeepsOneDecimal() {
        // "1/4 teaspoon" → 0.25 × 5 = 1.25 ml → whole-round would be 0, so fall
        // back to one decimal → "1.3 ml" (never "0 ml").
        #expect(IngredientMetricConverter.metric("1/4 teaspoon salt") == "1.3 ml salt")
    }

    @Test func eighthTeaspoonKeepsOneDecimal() {
        // "1/8 teaspoon" → 0.125 × 5 = 0.625 ml → whole-round would be 0, so fall
        // back to one decimal → "0.6 ml" (never "0 ml").
        #expect(IngredientMetricConverter.metric("1/8 teaspoon baking soda") == "0.6 ml baking soda")
    }

    @Test func halfTeaspoonKeepsOneDecimalNotFive() {
        // "1/2 teaspoon" → 0.5 × 5 = 2.5 ml. Nearest-5 rounding would snap this to
        // "5 ml", colliding it with a genuine 1 tsp — instead the sub-5 fallback
        // prints "2.5 ml", preserving the distinction.
        let result = IngredientMetricConverter.metric("1/2 teaspoon vanilla")
        #expect(result != "5 ml vanilla")
        #expect(result == "2.5 ml vanilla")
    }

    @Test func oneTeaspoonStillRoundsToWholeFive() {
        // 1 tsp is magnitude == 5 (not < 5), so it is NOT diverted to the sub-5
        // decimal fallback — it still reads the clean "5 ml".
        #expect(IngredientMetricConverter.metric("1 teaspoon salt") == "5 ml salt")
    }

    @Test func quarterTeaspoonUnchangedByHalfTeaspoonFix() {
        // ¼ tsp (1.25 ml) already used the fallback and must be unchanged: "1.3 ml".
        #expect(IngredientMetricConverter.metric("1/4 teaspoon salt") == "1.3 ml salt")
    }

    // MARK: - Micro-amounts below one-decimal resolution: never "0 ml"/"0 g" (DUT-540)

    @Test func microFractionTeaspoonShowsTraceMarker() {
        // "1/200 teaspoon" → 0.005 × 5 = 0.025 ml. Whole-round is 0 AND one
        // decimal (0.025 → "0.0" → trimmed "0") would still read as nothing, so
        // show the honest "<0.1 ml" trace marker — never a false "0 ml".
        let result = IngredientMetricConverter.metric("1/200 teaspoon xanthan")
        #expect(result != "0 ml xanthan")
        #expect(result == "<0.1 ml xanthan")
    }

    @Test func rawTinyDecimalTeaspoonShowsTraceMarker() {
        // "0.008 teaspoon" → 0.008 × 5 = 0.04 ml (< 0.05), same trace path.
        let result = IngredientMetricConverter.metric("0.008 teaspoon lecithin")
        #expect(result != "0 ml lecithin")
        #expect(result == "<0.1 ml lecithin")
    }

    @Test func microFractionPoundShowsTraceMarkerGrams() {
        // "1/400 pound" → 0.0025 × 450 = 1.125 g... use a smaller fraction to
        // drop below 0.05 g: "1/20000 pound" → 0.00005 × 450 = 0.0225 g → "<0.1 g".
        let result = IngredientMetricConverter.metric("1/20000 pound saffron")
        #expect(result != "0 g saffron")
        #expect(result == "<0.1 g saffron")
    }

    // MARK: - Rollover to litres / kilograms

    @Test func millilitersRollUpToLiters() {
        // "2 quarts" → 2 × 950 = 1900 ml → 1.9 L.
        #expect(IngredientMetricConverter.metric("2 quarts water") == "1.9 L water")
    }

    @Test func litersTrimTrailingZero() {
        // "4 cups" → 4 × 240 = 960 ml (< 1000, stays ml). Use pints for a clean L:
        // "5 pints" → 5 × 475 = 2375 ml → 2.375 → 2.4 L (one decimal).
        #expect(IngredientMetricConverter.metric("5 pints broth") == "2.4 L broth")
    }

    @Test func largeVolumeStaysOneDecimalLiters() {
        // "4 quarts" → 4 × 950 = 3800 ml → 3.8 L (one decimal, no trailing zero).
        #expect(IngredientMetricConverter.metric("4 quarts water") == "3.8 L water")
    }

    @Test func justUnderThousandMillilitersRollsUpNotThousandMl() {
        // "4.15 cups" → 4.15 × 240 = 996 ml. Raw magnitude is < 1000, but
        // `roundBase` snaps it to 1000, which used to print a nonsensical
        // "1000 ml". The roll-up now fires on the rounded value too → "1 L".
        let result = IngredientMetricConverter.metric("4.15 cups water")
        #expect(result != "1000 ml water")
        #expect(result == "1 L water")
    }

    @Test func gramsRollUpToKilograms() {
        // "3 pounds" → 3 × 450 = 1350 g → 1.35 → 1.4 kg.
        #expect(IngredientMetricConverter.metric("3 pounds flour") == "1.4 kg flour")
    }

    @Test func kilogramsTrimTrailingZero() {
        // "5 pounds" → 5 × 450 = 2250 g → 2.25 → 2.3 kg... verify one-decimal.
        #expect(IngredientMetricConverter.metric("5 pounds potatoes") == "2.3 kg potatoes")
    }

    // MARK: - Pass-through: count / descriptive units

    @Test func clovesPassThrough() {
        #expect(IngredientMetricConverter.metric("2 cloves garlic") == "2 cloves garlic")
    }

    @Test func canPassThrough() {
        #expect(IngredientMetricConverter.metric("1 can tomatoes") == "1 can tomatoes")
    }

    @Test func pinchPassThrough() {
        #expect(IngredientMetricConverter.metric("1 pinch nutmeg") == "1 pinch nutmeg")
    }

    // MARK: - Pass-through: already metric

    @Test func gramsPassThrough() {
        #expect(IngredientMetricConverter.metric("200 grams flour") == "200 grams flour")
    }

    @Test func milliliterPassThrough() {
        #expect(IngredientMetricConverter.metric("250 ml milk") == "250 ml milk")
    }

    // MARK: - Pass-through: non-parseable

    @Test func noQuantityPassThrough() {
        #expect(IngredientMetricConverter.metric("Salt to taste") == "Salt to taste")
    }

    @Test func noUnitPassThrough() {
        // A bare count with no unit ("2 eggs") has no metric target.
        #expect(IngredientMetricConverter.metric("2 eggs") == "2 eggs")
    }

    // MARK: - Scale-then-convert composition (render-path order)

    @Test func scaleThenConvertCup() {
        // "1 cup" scaled ×2 → "2 cups" → 2 × 240 = 480 ml → nearest 10 → 480.
        let scaled = FractionRenderer.scale("1 cup flour", by: 2)
        #expect(IngredientMetricConverter.metric(scaled) == "480 ml flour")
    }

    @Test func scaleThenConvertRollsToLiters() {
        // "1 quart" scaled ×3 → "3 quarts" → 3 × 950 = 2850 ml → 2.85 → 2.9 L.
        let scaled = FractionRenderer.scale("1 quart stock", by: 3)
        #expect(IngredientMetricConverter.metric(scaled) == "2.9 L stock")
    }
}

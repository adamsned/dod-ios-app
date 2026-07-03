import Testing

@testable import DODSupport

/// L1 coverage for the imperial→metric ingredient converter (DUT-517 — the
/// ingredient half of the unit toggle, the deferred other half of DUT-47).
///
/// Every expectation pins a user-facing contract: a convertible imperial
/// measurement is rewritten to metric (grams / millilitres, rolling up to
/// kilograms / litres past 1000) with cooking-friendly rounding — nearest 5
/// below 100, nearest 25 at or above 100 — while already-metric units,
/// count/descriptive units, and non-parseable lines pass through byte for byte.
///
/// The converter runs on the ALREADY-SCALED line, so the composition tests
/// scale first (via ``FractionRenderer``) and then convert, matching the render
/// path in Recipe Detail + the Cook Mode drawer.
@Suite("IngredientMetricConverter (DUT-517 ingredient half)")
struct IngredientMetricConverterTests {

    // MARK: - Volume → millilitres

    @Test func cupToMilliliters() {
        // 1 × 240 = 240 ml → nearest 25 → 250.
        #expect(IngredientMetricConverter.metric("1 cup flour") == "250 ml flour")
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
        // 1 × 475 = 475 ml → nearest 25 → 475.
        #expect(IngredientMetricConverter.metric("1 pint cream") == "475 ml cream")
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
        // 4 × 28 = 112 g → nearest 25 (>= 100) → 112/25 = 4.48 → 4 → 100.
        #expect(IngredientMetricConverter.metric("4 ounces cheese") == "100 g cheese")
    }

    @Test func singleOunceRoundsToNearestFive() {
        // 1 × 28 = 28 g → nearest 5 (< 100) → 30.
        #expect(IngredientMetricConverter.metric("1 ounce chocolate") == "30 g chocolate")
    }

    // MARK: - Mixed / fraction quantities

    @Test func mixedNumberCups() {
        // "1 1/2 cups" → 1.5 × 240 = 360 ml → nearest 25 → 360/25 = 14.4 → 14 → 350.
        #expect(IngredientMetricConverter.metric("1 1/2 cups milk") == "350 ml milk")
    }

    @Test func vulgarFractionCup() {
        // "½ cup" → 0.5 × 240 = 120 ml → nearest 25 → 120/25 = 4.8 → 5 → 125.
        #expect(IngredientMetricConverter.metric("½ cup sugar") == "125 ml sugar")
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
        // "1 cup" scaled ×2 → "2 cups" → 2 × 240 = 480 ml → nearest 25 →
        // 480/25 = 19.2 → 19 → 475.
        let scaled = FractionRenderer.scale("1 cup flour", by: 2)
        #expect(IngredientMetricConverter.metric(scaled) == "475 ml flour")
    }

    @Test func scaleThenConvertRollsToLiters() {
        // "1 quart" scaled ×3 → "3 quarts" → 3 × 950 = 2850 ml → 2.85 → 2.9 L.
        let scaled = FractionRenderer.scale("1 quart stock", by: 3)
        #expect(IngredientMetricConverter.metric(scaled) == "2.9 L stock")
    }
}

import Foundation
import Testing

@testable import DODSupport

/// DUT-915 — `metric(_:)` converts ingredient text derived from untrusted
/// JSON-LD. A pathological quantity ("99999999999999999999 cups flour") drives
/// the magnitude past `Int.max` on the L/kg roll-up path, where a bare
/// `Int(Double)` trapped (SIGTRAP) — crashing the recipe detail view. Same class
/// as `FractionRenderer` DUT-609 and `StepTimerParser` DUT-914. The guard
/// renders via the formatter instead of trapping, and leaves normal conversions
/// untouched.
@Suite("IngredientMetricConverter Int-overflow guard (DUT-915)")
struct IngredientMetricConverterOverflowTests {

    @Test func hugeQuantityWithNameDoesNotCrash() {
        // Must not SIGTRAP. The exact rendered magnitude is irrelevant (the input
        // is malformed) — only that it returns some non-empty string safely.
        let result = IngredientMetricConverter.metric("99999999999999999999 cups flour")
        #expect(!result.isEmpty)
    }

    @Test func hugePoundQuantityDoesNotCrash() {
        let result = IngredientMetricConverter.metric("50000000000000000 pounds beef")
        #expect(!result.isEmpty)
    }

    @Test func ordinaryConversionsAreUnchanged() {
        #expect(IngredientMetricConverter.metric("1 cup flour") == "240 ml flour")
        #expect(IngredientMetricConverter.metric("8 ounces cheese") == "230 g cheese")
        #expect(IngredientMetricConverter.metric("2 cups flour") == "480 ml flour")
        // A genuine litre roll-up still renders cleanly (not affected by the guard).
        #expect(IngredientMetricConverter.metric("5 quarts stock") == "4.8 L stock")
    }
}

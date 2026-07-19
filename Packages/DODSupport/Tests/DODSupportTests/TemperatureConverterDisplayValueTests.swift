import Testing

@testable import DODSupport

/// L1 coverage for ``TemperatureConverter/displayValue(fahrenheit:in:)`` — the
/// plain numeric convert-for-display helper added for callers (like the Heat
/// Coach nudge in `DODFeatureRecipeDetail`) that only hold a derived
/// Fahrenheit `Int` (``RecipeHeatProfile/Derived/ovenTempF``) rather than free
/// text, and need it rendered in the user's chosen display unit.
///
/// Rounding contract mirrors ``converting(_:to:)``: F→C rounds to the nearest
/// 5°C (cooking-friendly, matching how a cook reads an oven dial).
@Suite("TemperatureConverter.displayValue(fahrenheit:in:)")
struct TemperatureConverterDisplayValueTests {

    @Test func fahrenheitTargetReturnsValueUnchanged() {
        #expect(TemperatureConverter.displayValue(fahrenheit: 350, in: .fahrenheit) == 350)
    }

    @Test func celsiusTargetConvertsWithNearestFiveRounding() {
        // 350°F -> 176.66...°C -> rounded to the nearest 5°C = 175.
        #expect(TemperatureConverter.displayValue(fahrenheit: 350, in: .celsius) == 175)
    }

    @Test func celsiusTargetHandlesAnExactMultipleOfFive() {
        // 320°F -> exactly 160°C, no rounding drift.
        #expect(TemperatureConverter.displayValue(fahrenheit: 320, in: .celsius) == 160)
    }
}

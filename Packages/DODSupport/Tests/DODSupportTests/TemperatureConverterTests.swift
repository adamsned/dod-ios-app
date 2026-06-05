import Testing

@testable import DODSupport

/// L1 coverage for the recipe-step temperature unit toggle (DUT-47,
/// temperature half). Every expectation pins a user-facing contract:
/// an explicit-unit temperature in instruction text is rewritten to the
/// chosen unit with cooking-friendly rounding, while bare numbers,
/// times, quantities, and already-target-unit values are left untouched.
///
/// Detection is EXPLICIT-unit only by design: `350°F`, `350 °F`, `350F`,
/// `350 degrees F`, `350 degrees Fahrenheit` (+ the Celsius equivalents)
/// and ranges (`350-375°F`, `350 to 375°F`). Bare numbers ("bake at 350")
/// are intentionally NOT converted — see the bare-number tests below — to
/// avoid false positives on times/quantities. That is a documented
/// limitation (DUT-47 follow-up), not a bug.
///
/// Rounding contract: F→C rounds to the nearest 5°C; C→F rounds to the
/// nearest 5°F (matches how cooks read an oven dial). 350°F → 176.66°C →
/// 175°C; 175°C → 347°F → 345°F (note the asymmetry — a round-trip is not
/// guaranteed to return the exact original, by design).
@Suite("TemperatureConverter (DUT-47 temperature half)") struct TemperatureConverterTests {

    // MARK: - Single temperature, F → C

    @Test func degreeSymbolFahrenheitToCelsius() {
        let result = TemperatureConverter.converting("Preheat the oven to 350°F.", to: .celsius)
        #expect(result == "Preheat the oven to 175°C.")
    }

    @Test func spacedDegreeSymbolFahrenheitToCelsius() {
        // "350 °F" — a space between the number and the degree symbol.
        let result = TemperatureConverter.converting("Preheat to 350 °F now.", to: .celsius)
        #expect(result == "Preheat to 175 °C now.")
    }

    @Test func bareLetterFahrenheitToCelsius() {
        // "350F" — no degree symbol, unit letter glued to the number.
        let result = TemperatureConverter.converting("Heat to 350F.", to: .celsius)
        #expect(result == "Heat to 175C.")
    }

    @Test func degreesWordWithLetterFahrenheitToCelsius() {
        let result = TemperatureConverter.converting("Bake at 350 degrees F.", to: .celsius)
        #expect(result == "Bake at 175 degrees C.")
    }

    @Test func degreesWordSpelledOutFahrenheitToCelsius() {
        let result = TemperatureConverter.converting("Bake at 350 degrees Fahrenheit.", to: .celsius)
        #expect(result == "Bake at 175 degrees Celsius.")
    }

    @Test func spelledOutFahrenheitWordOnlyToCelsius() {
        // "350 Fahrenheit" with no "degrees" prefix and no symbol.
        let result = TemperatureConverter.converting("Roast at 425 Fahrenheit.", to: .celsius)
        #expect(result == "Roast at 220 Celsius.")
    }

    @Test func caseInsensitiveFahrenheitToCelsius() {
        let result = TemperatureConverter.converting("Heat to 350 degrees fahrenheit.", to: .celsius)
        #expect(result == "Heat to 175 degrees celsius.")
    }

    // MARK: - Single temperature, C → F

    @Test func degreeSymbolCelsiusToFahrenheit() {
        // 175°C → 347°F → nearest 5 → 345°F.
        let result = TemperatureConverter.converting("Preheat the oven to 175°C.", to: .fahrenheit)
        #expect(result == "Preheat the oven to 345°F.")
    }

    @Test func bareLetterCelsiusToFahrenheit() {
        let result = TemperatureConverter.converting("Heat to 200C.", to: .fahrenheit)
        // 200°C → 392°F → nearest 5 → 390°F.
        #expect(result == "Heat to 390F.")
    }

    @Test func degreesWordCelsiusToFahrenheit() {
        // 180°C → 356°F → nearest 5 → 355°F.
        let result = TemperatureConverter.converting("Bake at 180 degrees C.", to: .fahrenheit)
        #expect(result == "Bake at 355 degrees F.")
    }

    @Test func spelledOutCelsiusWordToFahrenheit() {
        let result = TemperatureConverter.converting("Bake at 180 degrees Celsius.", to: .fahrenheit)
        #expect(result == "Bake at 355 degrees Fahrenheit.")
    }

    // MARK: - Ranges (both ends convert)

    @Test func hyphenRangeFahrenheitToCelsius() {
        // 350°F → 175°C, 375°F → 190°C (190.55 → nearest 5).
        let result = TemperatureConverter.converting("Hold at 350-375°F.", to: .celsius)
        #expect(result == "Hold at 175-190°C.")
    }

    @Test func toWordRangeFahrenheitToCelsius() {
        let result = TemperatureConverter.converting("Hold at 350 to 375°F.", to: .celsius)
        #expect(result == "Hold at 175 to 190°C.")
    }

    @Test func rangeWithUnitOnEachEndFahrenheitToCelsius() {
        // Each end carries its own explicit unit.
        let result = TemperatureConverter.converting("Between 350°F and 400°F works.", to: .celsius)
        // 400°F → 204.44 → 205°C.
        #expect(result == "Between 175°C and 205°C works.")
    }

    // MARK: - Already-target-unit no-op

    @Test func alreadyCelsiusLeftUnchangedWhenTargetingCelsius() {
        let input = "Preheat the oven to 175°C."
        #expect(TemperatureConverter.converting(input, to: .celsius) == input)
    }

    @Test func alreadyFahrenheitLeftUnchangedWhenTargetingFahrenheit() {
        let input = "Preheat the oven to 350°F."
        #expect(TemperatureConverter.converting(input, to: .fahrenheit) == input)
    }

    // MARK: - Bare numbers left alone (documented limitation)

    @Test func bareNumberNoUnitLeftAlone() {
        // "bake at 350" with no F / ° / degrees — too ambiguous to convert.
        let input = "Bake at 350 until golden."
        #expect(TemperatureConverter.converting(input, to: .celsius) == input)
    }

    @Test func bareNumberWithDegreesButNoScaleLetterLeftAlone() {
        // "350 degrees" with no F/C/Fahrenheit/Celsius word: ambiguous, skip.
        let input = "Tilt it 90 degrees."
        #expect(TemperatureConverter.converting(input, to: .celsius) == input)
    }

    // MARK: - Non-temperature numbers left alone

    @Test func timeNumberLeftAlone() {
        let input = "Bake for 30 minutes."
        #expect(TemperatureConverter.converting(input, to: .celsius) == input)
    }

    @Test func quantityNumberLeftAlone() {
        let input = "Add 2 cups of flour and 1 teaspoon of salt."
        #expect(TemperatureConverter.converting(input, to: .celsius) == input)
    }

    @Test func temperatureConvertedButTimeUntouchedInSameString() {
        // Mixed: convert the 425°F, leave the "20 minutes" alone.
        let result = TemperatureConverter.converting(
            "Roast at 425°F for 20 minutes.",
            to: .celsius
        )
        // 425°F → 218.33 → 220°C.
        #expect(result == "Roast at 220°C for 20 minutes.")
    }

    // MARK: - Multiple temperatures in one string

    @Test func multipleTemperaturesAllConverted() {
        let result = TemperatureConverter.converting(
            "Sear at 450°F, then reduce to 325°F.",
            to: .celsius
        )
        // 450°F → 232.22 → 230°C; 325°F → 162.77 → 165°C.
        #expect(result == "Sear at 230°C, then reduce to 165°C.")
    }

    @Test func mixedUnitsBothConvertedToCelsius() {
        // A string that (oddly) mixes both — only the F value changes when
        // targeting Celsius; the C value is already in the target unit.
        let result = TemperatureConverter.converting(
            "Use 350°F or 175°C.",
            to: .celsius
        )
        #expect(result == "Use 175°C or 175°C.")
    }

    // MARK: - Decimal handling

    @Test func decimalTemperatureConverted() {
        // 212.0°F → 100°C exactly.
        let result = TemperatureConverter.converting("Bring to 212.0°F.", to: .celsius)
        #expect(result == "Bring to 100°C.")
    }

    // MARK: - No-temperature text untouched

    @Test func plainTextWithNoNumbersUntouched() {
        let input = "Stir until smooth and glossy."
        #expect(TemperatureConverter.converting(input, to: .celsius) == input)
    }

    @Test func emptyStringReturnsEmpty() {
        #expect(TemperatureConverter.converting("", to: .celsius).isEmpty)
    }

    // MARK: - False-positive guards on the bare unit letter

    @Test func wordStartingWithFafterNumberNotTreatedAsUnit() {
        // "5 Fresh" — the F begins a word, not a unit. Must not convert.
        let input = "Add 5 fresh basil leaves."
        #expect(TemperatureConverter.converting(input, to: .celsius) == input)
    }

    @Test func wordStartingWithCafterNumberNotTreatedAsUnit() {
        // "2 cups" must not be read as 2°C.
        let input = "Add 2 cups."
        #expect(TemperatureConverter.converting(input, to: .fahrenheit) == input)
    }

    // MARK: - Shared preference key + raw-value resolver

    @Test func preferenceKeyIsStableWireFormat() {
        // The UserDefaults key is the cross-package contract (Settings writes
        // it; Recipe Detail reads it via @AppStorage). Pin the exact string —
        // changing it silently strands every user's saved preference.
        #expect(TemperatureConverter.preferenceKey == "dod.settings.temperatureUnit")
    }

    @Test func resolvedUnitMapsKnownRawValues() {
        #expect(TemperatureConverter.resolvedUnit(fromRawValue: "fahrenheit") == .fahrenheit)
        #expect(TemperatureConverter.resolvedUnit(fromRawValue: "celsius") == .celsius)
    }

    @Test func resolvedUnitReturnsNilForRecipeDefaultAndUnknown() {
        // "recipeDefault" and any unknown / nil value mean "do not convert".
        #expect(TemperatureConverter.resolvedUnit(fromRawValue: "recipeDefault") == nil)
        #expect(TemperatureConverter.resolvedUnit(fromRawValue: "kelvin") == nil)
        #expect(TemperatureConverter.resolvedUnit(fromRawValue: nil) == nil)
    }
}

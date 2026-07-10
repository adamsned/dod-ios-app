import Testing

@testable import DODSupport

/// Regression tests locking the scale-word case-preservation contract of
/// TemperatureConverter.converting(_:to:). The converted scale token must
/// preserve the original's case style and form:
/// - all-uppercase source (length > 1) → UPPERCASE replacement
/// - leading-uppercase source → canonical Capitalized replacement
/// - otherwise → lowercase replacement
/// - single-letter form: "F" → "C", "f" → "c" (note: single letter does NOT trigger
///   the all-uppercase branch)
/// - both directions: to Celsius AND to Fahrenheit.
@Suite("TemperatureConverter Scale-Word Case Preservation (DUT-47)")
struct TemperatureConverterScaleWordCaseTests {

    // MARK: - Capitalized word (leading-uppercase)

    @Test func capitalizedFahrenheitToCelsius() {
        // "Fahrenheit" (canonical capitalized) → "Celsius".
        let result = TemperatureConverter.converting("Preheat to 350 degrees Fahrenheit.", to: .celsius)
        #expect(result == "Preheat to 175 degrees Celsius.")
    }

    @Test func capitalizedCelsiusToFahrenheit() {
        // "Celsius" (canonical capitalized) → "Fahrenheit".
        let result = TemperatureConverter.converting("Heat to 180 degrees Celsius.", to: .fahrenheit)
        #expect(result == "Heat to 355 degrees Fahrenheit.")
    }

    // MARK: - Lowercase word

    @Test func lowercaseFahrenheitToCelsius() {
        // "fahrenheit" (all lowercase) → "celsius" (all lowercase).
        let result = TemperatureConverter.converting("Bake at 350 degrees fahrenheit.", to: .celsius)
        #expect(result == "Bake at 175 degrees celsius.")
    }

    @Test func lowercaseCelsiusToFahrenheit() {
        // "celsius" (all lowercase) → "fahrenheit" (all lowercase).
        let result = TemperatureConverter.converting("Roast at 200 degrees celsius.", to: .fahrenheit)
        // 200°C → 392°F → 390°F.
        #expect(result == "Roast at 390 degrees fahrenheit.")
    }

    // MARK: - All-uppercase word

    @Test func allCapseFahrenheitToCelsius() {
        // "FAHRENHEIT" (all uppercase, length > 1) → "CELSIUS" (all uppercase).
        let result = TemperatureConverter.converting("Set to 350 DEGREES FAHRENHEIT.", to: .celsius)
        #expect(result == "Set to 175 DEGREES CELSIUS.")
    }

    @Test func allCapsCelsiusToFahrenheit() {
        // "CELSIUS" (all uppercase, length > 1) → "FAHRENHEIT" (all uppercase).
        let result = TemperatureConverter.converting("Maintain 180 DEGREES CELSIUS.", to: .fahrenheit)
        #expect(result == "Maintain 355 DEGREES FAHRENHEIT.")
    }

    // MARK: - Single-letter form: uppercase "F" and "C"

    @Test func singleLetterFahrenheitToCelsius() {
        // "F" (single letter, uppercase) → "C" (uppercase).
        // Note: single letter has length 1, so does NOT trigger the all-uppercase branch;
        // it matches leading-uppercase → canonical "C".
        let result = TemperatureConverter.converting("Heat to 350°F.", to: .celsius)
        #expect(result == "Heat to 175°C.")
    }

    @Test func singleLetterCelsiusToFahrenheit() {
        // "C" (single letter, uppercase) → "F" (uppercase).
        let result = TemperatureConverter.converting("Bake at 180°C.", to: .fahrenheit)
        #expect(result == "Bake at 355°F.")
    }

    // MARK: - Single-letter form: lowercase "f" and "c"

    @Test func singleLetterLowercaseFahrenheitToCelsius() {
        // "f" (single letter, lowercase) → "c" (lowercase).
        let result = TemperatureConverter.converting("Set oven to 350°f.", to: .celsius)
        #expect(result == "Set oven to 175°c.")
    }

    @Test func singleLetterLowercaseCelsiusToFahrenheit() {
        // "c" (single letter, lowercase) → "f" (lowercase).
        let result = TemperatureConverter.converting("Bring to 200°c.", to: .fahrenheit)
        #expect(result == "Bring to 390°f.")
    }

    // MARK: - Range: both ends respect case preservation

    @Test func rangeCapitalizedFahrenheitToCelsius() {
        // Both ends of "350°F to 375°F" are converted; case is preserved for each.
        let result = TemperatureConverter.converting("Hold at 350 to 375°F.", to: .celsius)
        // 350°F → 175°C; 375°F → 190°C.
        #expect(result == "Hold at 175 to 190°C.")
    }

    @Test func rangeAllCapsToFahrenheit() {
        // Each end carries its own DEGREES CELSIUS; both convert with case preserved.
        let result = TemperatureConverter.converting(
            "Between 175 DEGREES CELSIUS and 190 DEGREES CELSIUS.",
            to: .fahrenheit
        )
        // 175°C → 345°F; 190°C → 375°F.
        #expect(
            result == "Between 345 DEGREES FAHRENHEIT and 375 DEGREES FAHRENHEIT."
        )
    }

    // MARK: - Mixed case forms in one string

    @Test func mixedCaseFormsInSingleString() {
        // One Capitalized "Fahrenheit" and one lowercase "fahrenheit" in the same
        // string; each is converted with its case preserved.
        let result = TemperatureConverter.converting(
            "Start at 350 degrees Fahrenheit, then reduce to 325 degrees fahrenheit.",
            to: .celsius
        )
        // 350°F → 175°C; 325°F → 165°C.
        #expect(result == "Start at 175 degrees Celsius, then reduce to 165 degrees celsius.")
    }

    // MARK: - Already-target-unit letter forms (no conversion, case still intact)

    @Test func alreadyCelsiusCapitalizedLetter() {
        // Already in target Celsius; letter "C" is left as-is.
        let input = "Heat to 175°C."
        #expect(TemperatureConverter.converting(input, to: .celsius) == input)
    }

    @Test func alreadyFahrenheitLowercaseLetter() {
        // Already in target Fahrenheit; letter "f" is left as-is.
        let input = "Roast at 350°f."
        #expect(TemperatureConverter.converting(input, to: .fahrenheit) == input)
    }

    // MARK: - Decimal temperatures with case preservation

    @Test func decimalFahrenheitCapitalizedToCelsius() {
        // Decimal 212.0°F (exactly 100°C); case preserved (Capitalized).
        let result = TemperatureConverter.converting("Bring to 212.0°F.", to: .celsius)
        #expect(result == "Bring to 100°C.")
    }

    @Test func decimalCelsiusLowercaseToFahrenheit() {
        // Decimal 180.0°c (exactly 356°F, rounds to 355°F); case preserved (lowercase).
        let result = TemperatureConverter.converting("Heat to 180.0°c.", to: .fahrenheit)
        #expect(result == "Heat to 355°f.")
    }
}

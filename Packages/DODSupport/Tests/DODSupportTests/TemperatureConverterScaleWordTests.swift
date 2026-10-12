import Testing

@testable import DODSupport

/// Gap-coverage tests for TemperatureConverter.scaleWordOriginal and
/// TemperatureConverter.converted — case-preserving F<->C token re-spelling.
/// Covers both letter (F/C) and word (Fahrenheit/Celsius) forms across
/// uppercase, lowercase, and leading-uppercase case styles, in both
/// conversion directions.
@Suite("TemperatureConverter+ScaleWord case-preserving re-spelling")
struct TemperatureConverterScaleWordTests {

    // MARK: - scaleWordOriginal pass-through

    @Test func scaleWordOriginalLetterPassthrough() {
        let scaleWord = TemperatureConverter.ScaleWord.letter("F")
        #expect(TemperatureConverter.scaleWordOriginal(scaleWord) == "F")

        let lowercaseScaleWord = TemperatureConverter.ScaleWord.letter("f")
        #expect(TemperatureConverter.scaleWordOriginal(lowercaseScaleWord) == "f")
    }

    @Test func scaleWordOriginalWordPassthrough() {
        let scaleWord = TemperatureConverter.ScaleWord.word("Fahrenheit")
        #expect(TemperatureConverter.scaleWordOriginal(scaleWord) == "Fahrenheit")

        let lowercaseScaleWord = TemperatureConverter.ScaleWord.word("fahrenheit")
        #expect(TemperatureConverter.scaleWordOriginal(lowercaseScaleWord) == "fahrenheit")

        let uppercaseScaleWord = TemperatureConverter.ScaleWord.word("FAHRENHEIT")
        #expect(TemperatureConverter.scaleWordOriginal(uppercaseScaleWord) == "FAHRENHEIT")
    }

    // MARK: - converted with single letters, F → C

    @Test func convertedLetterUppercaseFahrenheitToCelsius() {
        let scaleWord = TemperatureConverter.ScaleWord.letter("F")
        let result = TemperatureConverter.converted(scaleWord, to: .celsius)
        // source "F": count=1 (not >1), first.isUppercase=true → canonical form
        #expect(result == "C")
    }

    @Test func convertedLetterLowercaseFahrenheitToCelsius() {
        let scaleWord = TemperatureConverter.ScaleWord.letter("f")
        let result = TemperatureConverter.converted(scaleWord, to: .celsius)
        // source "f": count=1 (not >1), first.isUppercase=false → lowercased
        #expect(result == "c")
    }

    // MARK: - converted with single letters, C → F

    @Test func convertedLetterUppercaseCelsiusToFahrenheit() {
        let scaleWord = TemperatureConverter.ScaleWord.letter("C")
        let result = TemperatureConverter.converted(scaleWord, to: .fahrenheit)
        // source "C": count=1 (not >1), first.isUppercase=true → canonical form
        #expect(result == "F")
    }

    @Test func convertedLetterLowercaseCelsiusToFahrenheit() {
        let scaleWord = TemperatureConverter.ScaleWord.letter("c")
        let result = TemperatureConverter.converted(scaleWord, to: .fahrenheit)
        // source "c": count=1 (not >1), first.isUppercase=false → lowercased
        #expect(result == "f")
    }

    // MARK: - converted with words (all-lowercase), F → C

    @Test func convertedWordAllLowercaseFahrenheitToCelsius() {
        let scaleWord = TemperatureConverter.ScaleWord.word("fahrenheit")
        let result = TemperatureConverter.converted(scaleWord, to: .celsius)
        // source "fahrenheit": count=10>1 but not all-uppercase → lowercased
        #expect(result == "celsius")
    }

    // MARK: - converted with words (leading-uppercase), F → C

    @Test func convertedWordLeadingUppercaseFahrenheitToCelsius() {
        let scaleWord = TemperatureConverter.ScaleWord.word("Fahrenheit")
        let result = TemperatureConverter.converted(scaleWord, to: .celsius)
        // source "Fahrenheit": count=10>1 but not all-uppercase, first.isUppercase=true → canonical
        #expect(result == "Celsius")
    }

    // MARK: - converted with words (all-uppercase), F → C

    @Test func convertedWordAllUppercaseFahrenheitToCelsius() {
        let scaleWord = TemperatureConverter.ScaleWord.word("FAHRENHEIT")
        let result = TemperatureConverter.converted(scaleWord, to: .celsius)
        // source "FAHRENHEIT": count=10>1 AND all-uppercase → uppercased
        #expect(result == "CELSIUS")
    }

    // MARK: - converted with words (all-lowercase), C → F

    @Test func convertedWordAllLowercaseCelsiusToFahrenheit() {
        let scaleWord = TemperatureConverter.ScaleWord.word("celsius")
        let result = TemperatureConverter.converted(scaleWord, to: .fahrenheit)
        // source "celsius": count=7>1 but not all-uppercase → lowercased
        #expect(result == "fahrenheit")
    }

    // MARK: - converted with words (leading-uppercase), C → F

    @Test func convertedWordLeadingUppercaseCelsiusToFahrenheit() {
        let scaleWord = TemperatureConverter.ScaleWord.word("Celsius")
        let result = TemperatureConverter.converted(scaleWord, to: .fahrenheit)
        // source "Celsius": count=7>1 but not all-uppercase, first.isUppercase=true → canonical
        #expect(result == "Fahrenheit")
    }

    // MARK: - converted with words (all-uppercase), C → F

    @Test func convertedWordAllUppercaseCelsiusToFahrenheit() {
        let scaleWord = TemperatureConverter.ScaleWord.word("CELSIUS")
        let result = TemperatureConverter.converted(scaleWord, to: .fahrenheit)
        // source "CELSIUS": count=7>1 AND all-uppercase → uppercased
        #expect(result == "FAHRENHEIT")
    }
}

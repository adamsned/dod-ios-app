import Testing

@testable import DODSupport

/// Regression tests locking the `readUnitSuffix` grammar: the contract that
/// a bare `°` or bare `degrees` with no scale letter/word is REJECTED (nil),
/// preventing false positives like "tilt 90 degrees" and "350°" from being
/// treated as temperatures. These tests ensure the unit-suffix grammar remains
/// enforced at the public `scan(_:)` level and the internal `readUnitSuffix`
/// boundary-check logic.
@Suite("TemperatureConverter unit-suffix grammar") struct TemperatureConverterUnitSuffixTests {

    // MARK: - Grammar acceptance: recognized temperatures

    @Test func recognizesDegreeSymbolWithFahrenheit() {
        // The minimal form: degree symbol + scale letter.
        let matches = TemperatureConverter.scan("Preheat to 350°F for baking.")
        #expect(!matches.isEmpty)
        let match = matches[0]
        #expect(match.scale == .fahrenheit)
        #expect(match.values.count == 1)
        #expect(match.values[0].magnitude == 350)
        #expect(match.unitSuffix == "°F")
        #expect(!match.range.isEmpty)
    }

    @Test func recognizesDegreeSymbolWithCelsius() {
        // Same form, Celsius variant.
        let matches = TemperatureConverter.scan("Set to 180°C.")
        #expect(!matches.isEmpty)
        let match = matches[0]
        #expect(match.scale == .celsius)
        #expect(match.values.count == 1)
        #expect(match.values[0].magnitude == 180)
        #expect(match.unitSuffix == "°C")
    }

    @Test func recognizesBareLetterAtBoundary() {
        // No degree symbol: just the number and the scale letter.
        let matches = TemperatureConverter.scan("Heat to 350F.")
        #expect(!matches.isEmpty)
        let match = matches[0]
        #expect(match.scale == .fahrenheit)
        if case .letter("F") = match.scaleWord {
            // Expected
        } else {
            #expect(Bool(false), "scaleWord should be .letter(\"F\")")
        }
    }

    @Test func recognizesDegreesWordWithLetter() {
        // The word "degrees" as prefix, then scale letter.
        let matches = TemperatureConverter.scan("Bake at 350 degrees fahrenheit.")
        #expect(!matches.isEmpty)
        let match = matches[0]
        #expect(match.scale == .fahrenheit)
        if case .word = match.scaleWord {
            // Expected
        } else {
            #expect(Bool(false), "scaleWord should be .word")
        }
    }

    @Test func recognizesDegreesWordWithSpelledScale() {
        // The word "degrees" + full spelled-out scale word.
        let matches = TemperatureConverter.scan("Set at 180 degrees Celsius.")
        #expect(!matches.isEmpty)
        let match = matches[0]
        #expect(match.scale == .celsius)
        if case .word = match.scaleWord {
            // Expected
        } else {
            #expect(Bool(false), "scaleWord should be .word")
        }
    }

    @Test func recognizesSpelledScaleWordAlone() {
        // Scale word without "degrees" prefix.
        let matches = TemperatureConverter.scan("Preheat to 425 Fahrenheit.")
        #expect(!matches.isEmpty)
        let match = matches[0]
        #expect(match.scale == .fahrenheit)
        if case .word = match.scaleWord {
            // Expected
        } else {
            #expect(Bool(false), "scaleWord should be .word")
        }
    }

    @Test func recognizesSpacedDegreeSymbol() {
        // Space before the degree symbol.
        let matches = TemperatureConverter.scan("Heat to 350 °F now.")
        #expect(!matches.isEmpty)
        let match = matches[0]
        #expect(match.scale == .fahrenheit)
        #expect(match.unitSuffix == " °F")
    }

    // MARK: - Grammar rejection: bare ° without scale

    @Test func rejectsBareDegreesSymbolWithoutScale() {
        // A bare `°` with no following scale letter/word must be rejected.
        // This is the key guard against "350°" being treated as a temperature.
        let matches = TemperatureConverter.scan("The temperature is 350°")
        #expect(matches.isEmpty)
    }

    @Test func rejectsBareDegreesSymbolInContext() {
        // Bare `°` within normal text (mid-sentence).
        let matches = TemperatureConverter.scan("It was 350° when I measured it.")
        #expect(matches.isEmpty)
    }

    // MARK: - Grammar rejection: degrees word without scale

    @Test func rejectsBareDegreesWordWithoutScale() {
        // The word "degrees" with no following scale letter/word must be rejected.
        // This is the key guard against "tilt 90 degrees" being treated as a
        // temperature.
        let matches = TemperatureConverter.scan("Tilt it 90 degrees.")
        #expect(matches.isEmpty)
    }

    @Test func rejectsBareDegreesWordInMiddleOfInstruction() {
        // Bare "degrees" in a normal cooking instruction (no scale signal).
        let matches = TemperatureConverter.scan("Rotate the pan 180 degrees every 10 minutes.")
        #expect(matches.isEmpty)
    }

    @Test func rejectsDegreeWordPlural() {
        // Plural "degrees" form also rejected without scale.
        let matches = TemperatureConverter.scan("Turn 45 degrees counterclockwise.")
        #expect(matches.isEmpty)
    }

    // MARK: - Word boundary enforcement: single-letter scale

    @Test func rejectsSingleLetterThatStartsAWord() {
        // "5 Fresh" — the F begins a new word, not a scale letter.
        // The word-boundary guard at isWordBoundary must reject this.
        let matches = TemperatureConverter.scan("Add 5 Fresh basil leaves.")
        #expect(matches.isEmpty)
    }

    @Test func rejectsCInCups() {
        // "2 cups" — the C begins the word "cups", not a scale letter.
        let matches = TemperatureConverter.scan("Stir in 2 cups of flour.")
        #expect(matches.isEmpty)
    }

    @Test func acceptsSingleLetterAtRealBoundary() {
        // "350f" with a space or punctuation after — valid.
        let matches = TemperatureConverter.scan("Heat to 350f.")
        #expect(!matches.isEmpty)
        #expect(matches[0].scale == .fahrenheit)
        if case .letter = matches[0].scaleWord {
            // Expected
        } else {
            #expect(Bool(false), "scaleWord should be .letter")
        }
    }

    // MARK: - Spelled-word boundary enforcement

    @Test func rejectsFahrenheitAsPrefixOfLongerWord() {
        // "fahrenheitlike" or "fahrenheitung" — the full word "fahrenheit" is
        // accepted only when followed by a word boundary.
        let matches = TemperatureConverter.scan("This is 350 fahrenheitung.")
        #expect(matches.isEmpty)
    }

    @Test func acceptsFahrenheitAsStandaloneWord() {
        // "fahrenheit" with proper word boundary (space or punctuation after).
        let matches = TemperatureConverter.scan("Set to 350 fahrenheit.")
        #expect(!matches.isEmpty)
        #expect(matches[0].scale == .fahrenheit)
        if case .word = matches[0].scaleWord {
            // Expected
        } else {
            #expect(Bool(false), "scaleWord should be .word")
        }
    }

    @Test func acceptsCelsiusAsStandaloneWord() {
        // Same for Celsius.
        let matches = TemperatureConverter.scan("Bake at 180 celsius.")
        #expect(!matches.isEmpty)
        #expect(matches[0].scale == .celsius)
        if case .word = matches[0].scaleWord {
            // Expected
        } else {
            #expect(Bool(false), "scaleWord should be .word")
        }
    }

    // MARK: - Case insensitivity

    @Test func acceptsLowercaseScale() {
        // "350 degrees fahrenheit" — all lowercase.
        let matches = TemperatureConverter.scan("Heat to 350 degrees fahrenheit.")
        #expect(!matches.isEmpty)
        let match = matches[0]
        #expect(match.scale == .fahrenheit)
        if case .word = match.scaleWord {
            // Expected
        } else {
            #expect(Bool(false), "scaleWord should be .word")
        }
    }

    @Test func acceptsMixedCaseScale() {
        // "350 Fahrenheit" with capital F.
        let matches = TemperatureConverter.scan("Heat to 350 Fahrenheit.")
        #expect(!matches.isEmpty)
        let match = matches[0]
        #expect(match.scale == .fahrenheit)
        if case .word = match.scaleWord {
            // Expected
        } else {
            #expect(Bool(false), "scaleWord should be .word")
        }
    }

    @Test func acceptsUppercaseScale() {
        // "350°F" with capital F.
        let matches = TemperatureConverter.scan("Heat to 350°F.")
        #expect(!matches.isEmpty)
        #expect(matches[0].scale == .fahrenheit)
    }

    @Test func acceptsLowercaseLetterScale() {
        // "350f" with lowercase.
        let matches = TemperatureConverter.scan("Heat to 350f.")
        #expect(!matches.isEmpty)
        #expect(matches[0].scale == .fahrenheit)
        if case .letter = matches[0].scaleWord {
            // Expected
        } else {
            #expect(Bool(false), "scaleWord should be .letter")
        }
    }

    // MARK: - Spacing variations

    @Test func acceptsSpaceBeforeScale() {
        // "350 F" with space before the scale letter.
        let matches = TemperatureConverter.scan("Heat to 350 F.")
        #expect(!matches.isEmpty)
        #expect(matches[0].scale == .fahrenheit)
    }

    @Test func acceptsMultipleSpacesBeforeDegreeSymbol() {
        // Spaces before the degree symbol are consumed.
        let matches = TemperatureConverter.scan("Heat to 350  °F.")
        #expect(!matches.isEmpty)
        #expect(matches[0].scale == .fahrenheit)
    }

    // MARK: - Mixed content (accepts temperature + rejects other numbers)

    @Test func acceptsTemperatureAndIgnoresBareNumber() {
        // Text with both an explicit-unit temperature and a bare number.
        let matches = TemperatureConverter.scan("Preheat to 350°F and wait 20 minutes.")
        #expect(matches.count == 1)
        #expect(matches[0].scale == .fahrenheit)
        #expect(matches[0].values[0].magnitude == 350)
    }

    @Test func acceptsMultipleTemperaturesInOneString() {
        // Two separate temperatures, both explicit-unit.
        let matches = TemperatureConverter.scan("Sear at 450°F then reduce to 325°F.")
        #expect(matches.count == 2)
        #expect(matches[0].scale == .fahrenheit)
        #expect(matches[0].values[0].magnitude == 450)
        #expect(matches[1].scale == .fahrenheit)
        #expect(matches[1].values[0].magnitude == 325)
    }
}

import Foundation
import Testing

@testable import DODSupport

@Suite("StepTimerParser.firstDuration") struct StepTimerParserTests {

    // MARK: - Required spec phrasings (T-305 plan)

    @Test func bakeMinutes() {
        #expect(StepTimerParser.firstDuration(in: "Bake for 30 minutes") == .seconds(30 * 60))
    }

    @Test func mixedHoursAndMinutes() {
        #expect(StepTimerParser.firstDuration(in: "Simmer for 1 hour 30 minutes") == .seconds(90 * 60))
    }

    @Test func mixedHoursAndMinutesWithAnd() {
        // "and" glue between units is common in recipe writing.
        #expect(StepTimerParser.firstDuration(in: "Bake for 1 hour and 15 minutes") == .seconds(75 * 60))
    }

    @Test func asciiFractionHours() {
        // "1 1/2 hours" → 90 min → 5400 s
        #expect(StepTimerParser.firstDuration(in: "Rest 1 1/2 hours") == .seconds(90 * 60))
    }

    @Test func decimalHours() {
        #expect(StepTimerParser.firstDuration(in: "Cook 1.5 hours") == .seconds(90 * 60))
    }

    @Test func secondsAbbreviation() {
        // "45 sec" exercises the abbreviation branch.
        #expect(StepTimerParser.firstDuration(in: "Whisk for 45 seconds") == .seconds(45))
    }

    @Test func wordNumeralIsRejected() {
        // We deliberately don't parse word numerals — call site shows no timer.
        #expect(StepTimerParser.firstDuration(in: "Boil ten minutes") == nil)
    }

    @Test func temperatureNotMistakenForDuration() {
        #expect(StepTimerParser.firstDuration(in: "Preheat the oven to 350°F") == nil)
    }

    @Test func noNumericInstructionReturnsNil() {
        #expect(StepTimerParser.firstDuration(in: "Stir vigorously") == nil)
    }

    // MARK: - Edge-case coverage

    @Test func unicodeHalfFraction() {
        // Hubbub-rendered recipe text sometimes uses the vulgar fraction directly.
        #expect(StepTimerParser.firstDuration(in: "Steep for ½ hour") == .seconds(30 * 60))
    }

    @Test func unicodeMixedNumber() {
        // "1 ½ hours" with a Unicode half.
        #expect(StepTimerParser.firstDuration(in: "Bake for 1 ½ hours") == .seconds(90 * 60))
    }

    @Test func singularUnitNoTrailingS() {
        // "1 minute" — singular spelling must still be recognized.
        #expect(StepTimerParser.firstDuration(in: "Wait 1 minute") == .seconds(60))
    }

    @Test func firstDurationWinsWhenMultiple() {
        // Two separate durations in the same sentence — we only need the first.
        let input = "Simmer 10 minutes, then cook another 30 minutes."
        #expect(StepTimerParser.firstDuration(in: input) == .seconds(10 * 60))
    }

    @Test func bareFractionWithoutWhole() {
        // "1/2 hour" with no leading whole number.
        #expect(StepTimerParser.firstDuration(in: "Rest 1/2 hour") == .seconds(30 * 60))
    }

    @Test func emptyStringReturnsNil() {
        #expect(StepTimerParser.firstDuration(in: "") == nil)
    }

    @Test func unitWordWithoutNumberReturnsNil() {
        // Just "minutes" with no quantity should not produce a duration.
        #expect(StepTimerParser.firstDuration(in: "After several minutes, stir.") == nil)
    }

    @Test func smallerUnitFollowingDoesNotOverflowSameOrLarger() {
        // "30 minutes 1 hour" should land on the first hit (30 min)
        // and ignore the larger follow-on unit — guard against bogus addition.
        #expect(StepTimerParser.firstDuration(in: "30 minutes 1 hour") == .seconds(30 * 60))
    }
}

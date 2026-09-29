import Foundation
import Testing

@testable import DODSupport

/// Edge-case and boundary coverage for ``StepTimerParser.firstDuration`` not
/// covered by the main test suite. Tests malformed input, overflow guards,
/// whitespace variations, all unit abbreviations, and Unicode fraction edge cases.
///
/// Spec trace: US-7 (Cook Mode inline timer).
@Suite("StepTimerParser Edge Cases") struct StepTimerParserEdgeCasesTests {

    // MARK: - Unicode vulgar fractions (full set, not just ½)

    @Test func vulgarThirdOfHour() {
        // ⅓ hour = 20 minutes = 1200 seconds
        #expect(StepTimerParser.firstDuration(in: "Steep for ⅓ hour") == .seconds(1200))
    }

    @Test func vulgarTwoThirdsOfMinute() {
        // ⅔ minute ≈ 40 seconds
        let result = StepTimerParser.firstDuration(in: "Wait ⅔ minute")
        guard let result else {
            Issue.record("Expected a duration, got nil")
            return
        }
        // 40/60 ≈ 0.6667; (0.6667 * 60) = 40 seconds
        #expect(result == .seconds(40))
    }

    @Test func vulgarQuarterHour() {
        // ¼ hour = 15 minutes = 900 seconds
        #expect(StepTimerParser.firstDuration(in: "Rest ¼ hour") == .seconds(900))
    }

    @Test func vulgarThreeQuartersHour() {
        // ¾ hour = 45 minutes = 2700 seconds
        #expect(StepTimerParser.firstDuration(in: "Bake ¾ hour") == .seconds(2700))
    }

    @Test func vulgarEighthSecond() {
        // ⅛ second = 0.125 seconds → rounds to 0, which fails the > 0 guard
        #expect(StepTimerParser.firstDuration(in: "Whisk ⅛ second") == nil)
    }

    // MARK: - Fractions with edge cases

    @Test func fractionWithZeroDenominator() {
        // "1/0 hours" → denominator guard catches this, returns nil
        #expect(StepTimerParser.firstDuration(in: "Bake 1/0 hours") == nil)
    }

    @Test func mixedNumberWithZeroDenominator() {
        // "2 1/0 hours" → the fraction part fails the denominator > 0 guard
        #expect(StepTimerParser.firstDuration(in: "Cook 2 1/0 hours") == nil)
    }

    @Test func decimalEndingInZero() {
        // "2.0 hours" should parse as exactly 2 hours
        #expect(StepTimerParser.firstDuration(in: "Bake 2.0 hours") == .seconds(7200))
    }

    @Test func decimalStartingWithZero() {
        // "0.5 hours" = 30 minutes
        #expect(StepTimerParser.firstDuration(in: "Wait 0.5 hours") == .seconds(1800))
    }

    @Test func decimalLeadingDot() {
        // ".5 hours" — the leading dot is skipped, and the parser finds "5 hours"
        #expect(StepTimerParser.firstDuration(in: "Steep .5 hours") == .seconds(18000))
    }

    // MARK: - Zero quantities

    @Test func zeroMinutes() {
        // "0 minutes" = 0 seconds, which fails the total > 0 guard
        #expect(StepTimerParser.firstDuration(in: "Wait 0 minutes") == nil)
    }

    @Test func zeroHours() {
        // "0 hours" = 0 seconds, rejected by > 0 guard
        #expect(StepTimerParser.firstDuration(in: "Bake 0 hours") == nil)
    }

    @Test func zeroWithFraction() {
        // "0 1/2 hours" = 0.5 hours = 1800 seconds (should work)
        #expect(StepTimerParser.firstDuration(in: "Rest 0 1/2 hours") == .seconds(1800))
    }

    // MARK: - All unit abbreviations

    @Test func unitAbbreviationHrs() {
        // "2 hrs" = 2 hours
        #expect(StepTimerParser.firstDuration(in: "Bake 2 hrs") == .seconds(7200))
    }

    @Test func unitAbbreviationHr() {
        // "1 hr" = 1 hour
        #expect(StepTimerParser.firstDuration(in: "Cook 1 hr") == .seconds(3600))
    }

    @Test func unitAbbreviationMins() {
        // "30 mins" = 30 minutes
        #expect(StepTimerParser.firstDuration(in: "Simmer 30 mins") == .seconds(1800))
    }

    @Test func unitAbbreviationMin() {
        // "15 min" = 15 minutes
        #expect(StepTimerParser.firstDuration(in: "Stir 15 min") == .seconds(900))
    }

    @Test func unitAbbreviationSecs() {
        // "45 secs" = 45 seconds
        #expect(StepTimerParser.firstDuration(in: "Whisk 45 secs") == .seconds(45))
    }

    @Test func unitAbbreviationSec() {
        // "30 sec" = 30 seconds
        #expect(StepTimerParser.firstDuration(in: "Count 30 sec") == .seconds(30))
    }

    // MARK: - Whitespace variations

    @Test func multipleLeadingSpaces() {
        // "   30 minutes" should still parse
        #expect(StepTimerParser.firstDuration(in: "   30 minutes") == .seconds(1800))
    }

    @Test func multipleTrailingSpaces() {
        // "30 minutes   " should parse
        #expect(StepTimerParser.firstDuration(in: "30 minutes   ") == .seconds(1800))
    }

    @Test func tabCharacter() {
        // "1\thour" — tab between quantity and unit
        #expect(StepTimerParser.firstDuration(in: "Bake 1\thour") == .seconds(3600))
    }

    @Test func newlineCharacter() {
        // "1\nhour" — newline between quantity and unit
        #expect(StepTimerParser.firstDuration(in: "Cook 1\nhour") == .seconds(3600))
    }

    @Test func multipleSpacesBetweenQuantityAndUnit() {
        // "30   minutes" — extra spaces
        #expect(StepTimerParser.firstDuration(in: "Simmer 30   minutes") == .seconds(1800))
    }

    @Test func multipleSpacesInGlue() {
        // "1 hour   and   30 minutes" — extra spaces around "and"
        #expect(StepTimerParser.firstDuration(in: "Bake 1 hour   and   30 minutes") == .seconds(5400))
    }

    // MARK: - Comma glue patterns

    @Test func commaGlueAlone() {
        // "1 hour, 30 minutes" — comma without "and"
        #expect(StepTimerParser.firstDuration(in: "Simmer 1 hour, 30 minutes") == .seconds(5400))
    }

    @Test func commaSpaceGlueMultipleTimes() {
        // "1 hour, 30 minutes, and 5 seconds"
        // This should parse "1 hour" as primary and "30 minutes" as follow-up;
        // the "and 5 seconds" part is too far from the glue-skipped index.
        #expect(StepTimerParser.firstDuration(in: "Simmer 1 hour, 30 minutes, and 5 seconds") == .seconds(5400))
    }

    // MARK: - Case insensitivity

    @Test func allUppercaseUnit() {
        // "30 MINUTES" should parse
        #expect(StepTimerParser.firstDuration(in: "Bake 30 MINUTES") == .seconds(1800))
    }

    @Test func mixedCaseUnit() {
        // "1 Hour" — initial cap on unit
        #expect(StepTimerParser.firstDuration(in: "Cook 1 Hour") == .seconds(3600))
    }

    @Test func allUppercaseQuantityAndUnit() {
        // "30 MINUTES" in all caps
        #expect(StepTimerParser.firstDuration(in: "BAKE FOR 30 MINUTES") == .seconds(1800))
    }

    // MARK: - Malformed fractions

    @Test func tripleFractionSlash() {
        // "1/2/3 minutes" — parses "1/2" (0.5), then "/" is not a whitespace or unit start,
        // so the scan looks for the next quantity+unit. Finds "3 minutes" = 180 seconds.
        #expect(StepTimerParser.firstDuration(in: "Wait 1/2/3 minutes") == .seconds(180))
    }

    @Test func fractionNoNumerator() {
        // "/2 hours" — the leading slash is skipped, parser finds "2 hours"
        #expect(StepTimerParser.firstDuration(in: "Bake /2 hours") == .seconds(7200))
    }

    @Test func fractionNoDenominator() {
        // "1/ hours" — the denominator scan finds no digits after the slash
        #expect(StepTimerParser.firstDuration(in: "Bake 1/ hours") == nil)
    }

    // MARK: - Overflow / very large values

    @Test func veryLargeIntegerHours() {
        // "999999999 hours" — a huge value that might overflow if not guarded
        let result = StepTimerParser.firstDuration(in: "Bake 999999999 hours")
        // The value parses, but the result is a Duration with a huge second count
        // We just verify it doesn't crash and returns a non-nil result.
        #expect(result != nil)
    }

    @Test func largeDecimal() {
        // "1.5e6 minutes" — parses "1.5" as a decimal, but "e" is not a digit or whitespace.
        // The scan continues and finds "6 minutes" = 360 seconds.
        #expect(StepTimerParser.firstDuration(in: "Bake 1.5e6 minutes") == .seconds(360))
    }

    // MARK: - Negative and special characters

    @Test func negativeSign() {
        // "-1 hours" — the "-" is not a digit, so the parser skips it and finds "1 hours"
        #expect(StepTimerParser.firstDuration(in: "Bake -1 hours") == .seconds(3600))
    }

    @Test func plusSign() {
        // "+5 minutes" — the "+" is not a digit, so parser skips it and finds "5 minutes"
        #expect(StepTimerParser.firstDuration(in: "Simmer +5 minutes") == .seconds(300))
    }

    // MARK: - Boundary cases for mixed follow-up

    @Test func mixedFollowUpImmediatelyAfterPrimary() {
        // DUT-248: the follow-up must begin IMMEDIATELY after the primary unit.
        // "1 hour 30 minutes" — no intervening words → should parse as 90 min.
        #expect(StepTimerParser.firstDuration(in: "Bake 1 hour 30 minutes") == .seconds(5400))
    }

    @Test func mixedFollowUpWithInterveningWords() {
        // "1 hour, then rest, 30 minutes" — the intervening "then rest" means
        // there's no immediate numeric after the glue-skipped index, so no follow-up.
        // Result: just the primary "1 hour".
        #expect(StepTimerParser.firstDuration(in: "Bake 1 hour, then rest, 30 minutes") == .seconds(3600))
    }

    @Test func mixedFollowUpSameSizeUnit() {
        // "30 minutes 30 seconds 1 hour" — seconds are smaller than minutes, so they add.
        // But the "1 hour" follows and is larger than minutes, so it's ignored.
        #expect(StepTimerParser.firstDuration(in: "Simmer 30 minutes 30 seconds 1 hour") == .seconds(1830))
    }

    @Test func mixedFollowUpMultipleSmaller() {
        // "1 hour 30 minutes 45 seconds"
        // After "1 hour", look for follow-up: found "30 minutes" (smaller).
        // Add it. Look past "30 minutes" for another: found "45 seconds" (even smaller than minutes).
        // But the code only checks ONE follow-up (mixedFollowUp returns after the first).
        // So: 1 hour (3600s) + 30 minutes (1800s) = 5400s. The "45 seconds" is not consumed.
        #expect(StepTimerParser.firstDuration(in: "Bake 1 hour 30 minutes 45 seconds") == .seconds(5400))
    }

    // MARK: - Numeric edge cases in parsing

    @Test func singleDigitQuantity() {
        // "1 minute" should parse
        #expect(StepTimerParser.firstDuration(in: "Wait 1 minute") == .seconds(60))
    }

    @Test func multiDigitQuantity() {
        // "123 seconds" should parse
        #expect(StepTimerParser.firstDuration(in: "Whisk 123 seconds") == .seconds(123))
    }

    @Test func quantityFollowedImmediatelyByUnit() {
        // "30minutes" (no space) — the quantity scan stops at the "m" (not a digit),
        // then the unit scan tries to read from the "m". This should still work
        // because skipWhitespace is permissive.
        let result = StepTimerParser.firstDuration(in: "Simmer 30minutes")
        // Actually, after parsing "30", afterSpace points to "m", which skipWhitespace
        // leaves unchanged (not whitespace). Then readUnit looks for "minutes" starting
        // at "m", and it finds it. So this should work.
        #expect(result == .seconds(1800))
    }

    // MARK: - Attached Unicode vulgar fraction (no Linear ticket — found during bug-hunt)

    @Test func attachedVulgarFractionRealRecipeInstruction() {
        // Exact live WPRM instruction text (dutchovendaddy.com pork
        // belly burnt ends), decoded from "&frac12;" — the digit and the
        // fraction glyph sit with no space between them. Before the fix,
        // `scanInteger` swallowed "½" into the same digit scan as "2"
        // (Character.isNumber is true for vulgar fractions too), producing
        // the unparsable substring "2½", silently defaulting the quantity to
        // 0, and returning nil — no Cook Mode timer at all for this step.
        let input =
            "Braise for 2 to 2½ hours, until internal temperature reaches "
            + "200-205°F and cubes are fork-tender. Check temperature at the 2-hour mark."
        #expect(StepTimerParser.firstDuration(in: input) == .seconds(9000))
    }

    @Test func attachedVulgarFractionHours() {
        // "2½ hours" (no space) must resolve to 2.5 hours, matching the
        // already-supported spaced form "2 ½ hours".
        #expect(StepTimerParser.firstDuration(in: "Bake for 2½ hours") == .seconds(9000))
    }

    @Test func attachedVulgarFractionOneAndAHalf() {
        // "1½ hours" (no space) → 90 minutes, same value as the existing
        // spaced-form test `unicodeMixedNumber` ("1 ½ hours").
        #expect(StepTimerParser.firstDuration(in: "Bake for 1½ hours") == .seconds(90 * 60))
    }

    @Test func attachedVulgarQuarterMinutes() {
        // "10¼ minutes" (no space) → 10.25 * 60 = 615 seconds.
        #expect(StepTimerParser.firstDuration(in: "Wait 10¼ minutes") == .seconds(615))
    }

    @Test func plainIntegerStillStopsAtNonDigit() {
        // Regression guard for the `scanInteger` fix itself: an ordinary
        // integer quantity followed by a non-fraction, non-digit character
        // must still stop cleanly at that character (unaffected by
        // restricting the scan to ASCII digits).
        #expect(StepTimerParser.firstDuration(in: "Bake for 20 minutes.") == .seconds(20 * 60))
    }

    // MARK: - Rounding and precision

    @Test func fractionRoundingToInteger() {
        // "0.99 hours" → should round in the final Duration?
        // Actually, the code does: baseSeconds = Int((0.99 * 3600).rounded())
        // = Int((3564).rounded()) = 3564 seconds.
        #expect(StepTimerParser.firstDuration(in: "Bake 0.99 hours") == .seconds(3564))
    }

    @Test func fractionRoundingDownToSmall() {
        // "0.001 hours" → Int((0.001 * 3600).rounded()) = Int((3.6).rounded()) = 4s
        #expect(StepTimerParser.firstDuration(in: "Wait 0.001 hours") == .seconds(4))
    }
}

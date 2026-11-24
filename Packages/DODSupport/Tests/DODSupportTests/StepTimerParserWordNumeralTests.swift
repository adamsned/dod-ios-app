import Foundation
import Testing

@testable import DODSupport

/// Word-numeral coverage for ``StepTimerParser.firstDuration`` (DUT-1869).
@Suite("StepTimerParser Word Numerals") struct StepTimerParserWordNumeralTests {

    @Test func wordNumeralInsideWordIsIgnored() {
        // "often" contains "ten" but is not a numeral.
        #expect(StepTimerParser.firstDuration(in: "Stir often, minutes later") == nil)
    }

    @Test func wordNumeralFortyFiveHyphenated() {
        #expect(StepTimerParser.firstDuration(in: "Simmer forty-five minutes") == .seconds(2700))
    }

    @Test func articleAnHour() {
        #expect(StepTimerParser.firstDuration(in: "Rest an hour") == .seconds(3600))
    }
}

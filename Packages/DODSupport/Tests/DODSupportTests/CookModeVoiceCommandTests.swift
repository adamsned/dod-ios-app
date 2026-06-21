import Testing

@testable import DODSupport

/// L1 coverage for the Cook Mode voice-command grammar (US-49 / DUT-101). Pure
/// transcript→command mapping, so no microphone is involved.
@Suite("CookModeVoiceCommand (DUT-101)")
struct CookModeVoiceCommandTests {

    @Test func recognizesNextSynonyms() {
        for phrase in ["next", "Next", "next step", "go on", "continue", "go to the next one"] {
            #expect(CookModeVoiceCommand.parse(phrase) == .next)
        }
    }

    @Test func recognizesPreviousSynonyms() {
        for phrase in ["back", "previous", "go back", "previous step", "the last step"] {
            #expect(CookModeVoiceCommand.parse(phrase) == .previous)
        }
    }

    @Test func recognizesRepeatSynonyms() {
        for phrase in ["repeat", "say that again", "again", "what was that"] {
            #expect(CookModeVoiceCommand.parse(phrase) == .repeatStep)
        }
    }

    @Test func recognizesStartTimerSynonyms() {
        for phrase in ["start a timer", "set a timer", "start the timer", "set timer"] {
            #expect(CookModeVoiceCommand.parse(phrase) == .startTimer)
        }
    }

    @Test func startTimerWinsOverNavigationKeywords() {
        // A timer request must not be misread as navigation even if it's wordy.
        #expect(CookModeVoiceCommand.parse("hey can you start a timer") == .startTimer)
    }

    @Test func recognizesPauseSynonyms() {
        for phrase in ["pause", "hold on", "wait", "stop"] {
            #expect(CookModeVoiceCommand.parse(phrase) == .pause)
        }
    }

    @Test func unrecognizedOrEmptyIsUnknown() {
        #expect(CookModeVoiceCommand.parse("") == .unknown)
        #expect(CookModeVoiceCommand.parse("   ") == .unknown)
        #expect(CookModeVoiceCommand.parse("how much garlic") == .unknown)
    }

    @Test func parsingIsCaseInsensitive() {
        #expect(CookModeVoiceCommand.parse("NEXT STEP") == .next)
        #expect(CookModeVoiceCommand.parse("Start A Timer") == .startTimer)
    }
}

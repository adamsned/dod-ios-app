import DODSupport
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// L1 coverage for ``VoiceReader`` (US-40 / AC-40.2 + AC-40.4 + AC-40.6 +
/// AC-40.7). A ``MockSpeechSynthesizer`` stands in for `AVSpeechSynthesizer`
/// so the reader's state machine is asserted with zero real-audio dependency
/// (CL-79). No simulator, no audio session — the iOS-only session work is
/// compiled out on the macOS test slice behind `#if os(iOS)`.
@MainActor
@Suite("VoiceReader (US-40)") struct VoiceReaderTests {

    @Test func speakEntersSpeakingState() {
        let mock = MockSpeechSynthesizer()
        let reader = VoiceReader(synthesizer: mock)

        reader.speak("Preheat the oven to 350 degrees.")

        #expect(reader.isSpeaking)
        #expect(!reader.isPaused)
    }

    @Test func stopReturnsToStoppedState() {
        let mock = MockSpeechSynthesizer()
        let reader = VoiceReader(synthesizer: mock)
        reader.speak("Stir in the flour.")

        reader.stop()

        #expect(!reader.isSpeaking)
        #expect(!reader.isPaused)
    }

    @Test func pauseEntersPausedState() {
        let mock = MockSpeechSynthesizer()
        let reader = VoiceReader(synthesizer: mock)
        reader.speak("Simmer for twenty minutes.")

        reader.pause()

        #expect(reader.isPaused)
        #expect(!reader.isSpeaking)
    }

    @Test func resumeReturnsToSpeakingState() {
        let mock = MockSpeechSynthesizer()
        let reader = VoiceReader(synthesizer: mock)
        reader.speak("Fold in the egg whites.")
        reader.pause()
        #expect(reader.isPaused)

        reader.resume()

        #expect(reader.isSpeaking)
        #expect(!reader.isPaused)
    }

    /// AC-40.7: speaking a new step while one is already in flight must stop
    /// the prior utterance *before* enqueuing the new one, so two voices
    /// never overlap when steps change quickly.
    @Test func speakingNewTextWhileSpeakingStopsPriorUtteranceFirst() {
        let mock = MockSpeechSynthesizer()
        let reader = VoiceReader(synthesizer: mock)

        reader.speak("Step one: chop the onion.")
        reader.speak("Step two: heat the oil.")

        // AC-40.7 contract: a stop must sit between the two speaks so the
        // prior utterance is torn down before the new one starts. (speak(_:)
        // also defensively stops before the very first utterance, so the full
        // log is stop, speak(1), stop, speak(2) — what matters is the stop
        // immediately preceding the second speak.)
        let firstSpeak = mock.calls.firstIndex(of: .speak("Step one: chop the onion."))
        let secondSpeak = mock.calls.firstIndex(of: .speak("Step two: heat the oil."))
        #expect(firstSpeak != nil)
        #expect(secondSpeak != nil)
        if let firstSpeak, let secondSpeak {
            #expect(secondSpeak > firstSpeak)
            // The call directly before the second speak is a stop.
            #expect(mock.calls[secondSpeak - 1] == .stop)
        }
        // And the reader still ends up speaking the step the user landed on.
        #expect(reader.isSpeaking)
    }

    @Test func speakRecordsTheSpokenText() {
        let mock = MockSpeechSynthesizer()
        let reader = VoiceReader(synthesizer: mock)

        reader.speak("Add a pinch of salt.")

        #expect(mock.spokenTexts == ["Add a pinch of salt."])
    }

    /// Blank / whitespace-only step text is a no-op — the reader must not
    /// enqueue an empty utterance (defensive, and keeps the engine quiet on a
    /// step that has no instruction body).
    @Test func speakingBlankTextIsANoOp() {
        let mock = MockSpeechSynthesizer()
        let reader = VoiceReader(synthesizer: mock)

        reader.speak("   \n  ")

        #expect(mock.calls.isEmpty)
        #expect(!reader.isSpeaking)
    }

    @Test func stoppingWhenIdleIsSafe() {
        let mock = MockSpeechSynthesizer()
        let reader = VoiceReader(synthesizer: mock)

        reader.stop()

        #expect(!reader.isSpeaking)
        #expect(!reader.isPaused)
    }

    /// DUT-283 — after an audio interruption (call / Siri / route change) tears
    /// down our session, the next `speak(_:)` must re-activate it. Before the fix
    /// the one-shot `didActivateAudioSession` flag stayed true forever, so Voice
    /// Mode went permanently silent (or stopped ducking) for the rest of the cook.
    @Test func interruptionInvalidationForcesReactivationOnTheNextSpeak() {
        let reader = VoiceReader(synthesizer: MockSpeechSynthesizer())
        reader.speak("Step one.")
        #expect(reader.hasActiveAudioSession)

        reader.invalidateAudioSession()  // what the interruption observer does on .began
        #expect(!reader.hasActiveAudioSession)

        reader.speak("Step two.")
        #expect(reader.hasActiveAudioSession)  // recovered — not silent for the session
    }
}

/// Records calls + flips its own speaking/paused flags so ``VoiceReader``'s
/// contract can be asserted without `AVSpeechSynthesizer` or any audio
/// hardware. Mirrors the in-memory stub pattern the Cook Mode Live Activity
/// tests use for ``CookLiveActivityController`` (US-11).
@MainActor
final class MockSpeechSynthesizer: SpeechSynthesizing {

    enum Call: Equatable {
        case speak(String)
        case stop
        case pause
        case continueSpeaking
    }

    private(set) var calls: [Call] = []
    private(set) var spokenTexts: [String] = []

    private(set) var isSpeaking = false
    private(set) var isPaused = false

    /// DUT-328 — the catalog `installedVoiceDescriptors()` returns. Default
    /// empty (reads as "unknown" → no upgrade prompt); tests set it to exercise
    /// the natural-voice check.
    var stubbedVoices: [VoiceDescriptor] = []

    func installedVoiceDescriptors() -> [VoiceDescriptor] { stubbedVoices }

    func speak(_ text: String) {
        calls.append(.speak(text))
        spokenTexts.append(text)
        isSpeaking = true
        isPaused = false
    }

    func stop() {
        calls.append(.stop)
        isSpeaking = false
        isPaused = false
    }

    func pause() {
        calls.append(.pause)
        if isSpeaking {
            isPaused = true
            isSpeaking = false
        }
    }

    func continueSpeaking() {
        calls.append(.continueSpeaking)
        if isPaused {
            isPaused = false
            isSpeaking = true
        }
    }
}

import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// L1 coverage for the in-app Voice Mode wiring on ``CookModeViewModel``
/// (US-40 / T-690b — AC-40.1 toggle, AC-40.3 re-read on step change, and the
/// AC-40.5 control surface the T-690c App Intents will call).
///
/// Each test injects a real ``VoiceReader`` driven by a ``MockSpeechSynthesizer``
/// (defined alongside ``VoiceReaderTests``) so the toggle / re-read / pause /
/// stop contract is asserted with zero real-audio dependency (CL-79 / CL-81).
/// The step bodies the shared `makeViewModel` helper produces are
/// `"Step 1 body."`, `"Step 2 body."`, … so the spoken-text assertions read
/// against those.
@MainActor
@Suite("CookModeViewModel Voice Mode (US-40)") struct CookModeVoiceModeTests {

    /// AC-40.1 — Voice Mode is off every time Cook Mode is entered.
    @Test func voiceModeIsOffByDefault() {
        let viewModel = CookModeViewModelTests.makeViewModel(stepCount: 3)
        #expect(!viewModel.isVoiceModeEnabled)
    }

    /// AC-40.1 + AC-40.2 — toggling Voice Mode on immediately reads the
    /// current step aloud.
    @Test func turningVoiceModeOnSpeaksTheCurrentStep() {
        let mock = MockSpeechSynthesizer()
        let viewModel = CookModeViewModelTests.makeViewModel(
            stepCount: 3,
            voiceReader: VoiceReader(synthesizer: mock)
        )

        viewModel.setVoiceMode(true)

        #expect(viewModel.isVoiceModeEnabled)
        #expect(mock.spokenTexts == ["Step 1 body."])
    }

    /// AC-40.3 — advancing a step while Voice Mode is on re-reads the new step.
    @Test func stepChangeReReadsWhileVoiceModeOn() {
        let mock = MockSpeechSynthesizer()
        let viewModel = CookModeViewModelTests.makeViewModel(
            stepCount: 3,
            voiceReader: VoiceReader(synthesizer: mock)
        )
        viewModel.setVoiceMode(true)  // speaks step 1

        viewModel.advanceStep()  // -> step 2
        viewModel.previousStep()  // -> step 1

        #expect(mock.spokenTexts == ["Step 1 body.", "Step 2 body.", "Step 1 body."])
    }

    /// On-screen Next/Previous (which call goNext/goBack directly) re-read too —
    /// the re-read driver hangs off navigation, not just the voice-command
    /// wrappers (AC-40.3).
    @Test func onScreenNavigationAlsoReReads() {
        let mock = MockSpeechSynthesizer()
        let viewModel = CookModeViewModelTests.makeViewModel(
            stepCount: 3,
            voiceReader: VoiceReader(synthesizer: mock)
        )
        viewModel.setVoiceMode(true)

        viewModel.goNext()

        #expect(mock.spokenTexts == ["Step 1 body.", "Step 2 body."])
    }

    /// AC-40.3 — reaching the Done state speaks a completion line, not a step.
    @Test func reachingDoneSpeaksCompletionLine() {
        let mock = MockSpeechSynthesizer()
        let viewModel = CookModeViewModelTests.makeViewModel(
            stepCount: 1,
            voiceReader: VoiceReader(synthesizer: mock)
        )
        viewModel.setVoiceMode(true)  // speaks the single step

        viewModel.advanceStep()  // -> finished

        #expect(viewModel.isFinished)
        #expect(mock.spokenTexts.last == "All done — enjoy your meal")
    }

    /// AC-40.5 — "repeat" re-speaks the same step without moving position.
    @Test func repeatReReadsTheSameStep() {
        let mock = MockSpeechSynthesizer()
        let viewModel = CookModeViewModelTests.makeViewModel(
            stepCount: 3,
            voiceReader: VoiceReader(synthesizer: mock)
        )
        viewModel.setVoiceMode(true)
        viewModel.advanceStep()  // -> step 2

        viewModel.repeatCurrentStep()

        #expect(viewModel.currentStepIndex == 1)
        #expect(mock.spokenTexts == ["Step 1 body.", "Step 2 body.", "Step 2 body."])
    }

    /// AC-40.4 / AC-40.5 — "pause" pauses the current utterance.
    @Test func pauseVoicePausesTheReader() {
        let mock = MockSpeechSynthesizer()
        let viewModel = CookModeViewModelTests.makeViewModel(
            stepCount: 3,
            voiceReader: VoiceReader(synthesizer: mock)
        )
        viewModel.setVoiceMode(true)

        viewModel.pauseVoice()

        #expect(mock.calls.contains(.pause))
        #expect(mock.isPaused)
    }

    /// AC-40.1 — toggling Voice Mode off stops the reader and disables the flag.
    @Test func turningVoiceModeOffStopsTheReader() {
        let mock = MockSpeechSynthesizer()
        let viewModel = CookModeViewModelTests.makeViewModel(
            stepCount: 3,
            voiceReader: VoiceReader(synthesizer: mock)
        )
        viewModel.setVoiceMode(true)
        #expect(mock.isSpeaking)

        viewModel.setVoiceMode(false)

        #expect(!viewModel.isVoiceModeEnabled)
        #expect(!mock.isSpeaking)
        #expect(mock.calls.last == .stop)
    }

    /// While Voice Mode is off, navigation must stay silent — no utterance the
    /// user didn't ask for.
    @Test func navigationIsSilentWhileVoiceModeOff() {
        let mock = MockSpeechSynthesizer()
        let viewModel = CookModeViewModelTests.makeViewModel(
            stepCount: 3,
            voiceReader: VoiceReader(synthesizer: mock)
        )

        viewModel.goNext()
        viewModel.advanceStep()
        viewModel.repeatCurrentStep()

        #expect(mock.calls.isEmpty)
    }

    /// AC-7.6 — exiting Cook Mode stops the reader and clears Voice Mode.
    @Test func endCookModeStopsTheReader() {
        let mock = MockSpeechSynthesizer()
        let viewModel = CookModeViewModelTests.makeViewModel(
            stepCount: 3,
            voiceReader: VoiceReader(synthesizer: mock)
        )
        viewModel.beginCookMode()
        viewModel.setVoiceMode(true)
        #expect(mock.isSpeaking)

        viewModel.endCookMode()

        #expect(!viewModel.isVoiceModeEnabled)
        #expect(!mock.isSpeaking)
        #expect(mock.calls.last == .stop)
    }
}

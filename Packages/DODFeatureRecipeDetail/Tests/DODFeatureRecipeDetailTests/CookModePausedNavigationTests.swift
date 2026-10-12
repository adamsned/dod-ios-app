import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// DUT-1393 — pausing the voice and then changing steps must NOT start the voice
/// again on its own. It stays paused (silent); the next play reads the step now
/// on screen from the top, not the old step's half-finished sentence.
@MainActor
@Suite("Cook Mode: paused voice stays paused across steps (DUT-1393)")
struct CookModePausedNavigationTests {

    private func pausedOnStepOne() -> (CookModeViewModel, MockSpeechSynthesizer) {
        let mock = MockSpeechSynthesizer()
        let viewModel = CookModeViewModelTests.makeViewModel(
            stepCount: 3,
            voiceReader: VoiceReader(synthesizer: mock)
        )
        viewModel.togglePlayback()  // idle -> speaking "Step 1 body."
        viewModel.togglePlayback()  // speaking -> paused
        return (viewModel, mock)
    }

    @Test func nextWhilePausedStaysSilentAndPaused() {
        let (viewModel, mock) = pausedOnStepOne()

        viewModel.goNext()

        #expect(viewModel.currentStepIndex == 1)
        #expect(viewModel.playbackState == .paused)
        #expect(!viewModel.isPlaying)
        // Only the original step-1 read; nothing new was spoken or resumed.
        #expect(mock.spokenTexts == ["Step 1 body."])
        #expect(!mock.calls.contains(.continueSpeaking))
    }

    @Test func backWhilePausedStaysSilentAndPaused() {
        let (viewModel, mock) = pausedOnStepOne()
        viewModel.togglePlayback()  // resume step 1
        viewModel.goNext()  // speaking -> reads step 2
        viewModel.togglePlayback()  // pause on step 2

        viewModel.goBack()

        #expect(viewModel.currentStepIndex == 0)
        #expect(viewModel.playbackState == .paused)
        #expect(mock.spokenTexts == ["Step 1 body.", "Step 2 body."])
    }

    /// Play after paging while paused reads the NEW step from the beginning
    /// (a fresh `speak`), never `continueSpeaking` on the old step's utterance.
    @Test func resumeAfterPagingReadsTheNewStepFromTheTop() {
        let (viewModel, mock) = pausedOnStepOne()
        viewModel.goNext()
        viewModel.goNext()

        viewModel.togglePlayback()

        #expect(viewModel.currentStepIndex == 2)
        #expect(viewModel.playbackState == .speaking)
        #expect(mock.spokenTexts == ["Step 1 body.", "Step 3 body."])
        #expect(!mock.calls.contains(.continueSpeaking))
    }

    /// The paused utterance is dropped on the step change, so the old step can't
    /// be continued later by anything.
    @Test func pagingWhilePausedStopsTheOldUtterance() {
        let (viewModel, mock) = pausedOnStepOne()

        viewModel.goNext()

        #expect(mock.calls.last == .stop)
        #expect(viewModel.playbackState == .paused)
    }

    /// A plain pause/resume on the SAME step still continues in place (DUT-583).
    @Test func resumeOnTheSameStepStillContinuesInPlace() {
        let (viewModel, mock) = pausedOnStepOne()

        viewModel.togglePlayback()

        #expect(mock.calls.contains(.continueSpeaking))
        #expect(mock.spokenTexts == ["Step 1 body."])
    }

    /// Navigation while playing still re-reads each step (AC-40.3 unchanged).
    @Test func nextWhilePlayingStillReadsTheNewStep() {
        let mock = MockSpeechSynthesizer()
        let viewModel = CookModeViewModelTests.makeViewModel(
            stepCount: 3,
            voiceReader: VoiceReader(synthesizer: mock)
        )
        viewModel.togglePlayback()

        viewModel.goNext()

        #expect(viewModel.playbackState == .speaking)
        #expect(mock.spokenTexts == ["Step 1 body.", "Step 2 body."])
    }

    /// A Siri "Resume" after paging while paused also reads the new step.
    @Test func siriResumeAfterPagingReadsTheNewStep() {
        let (viewModel, mock) = pausedOnStepOne()
        viewModel.advanceStep()  // Siri "Next step"

        viewModel.resumeVoice()  // Siri "Resume"

        #expect(viewModel.playbackState == .speaking)
        #expect(mock.spokenTexts == ["Step 1 body.", "Step 2 body."])
    }
}

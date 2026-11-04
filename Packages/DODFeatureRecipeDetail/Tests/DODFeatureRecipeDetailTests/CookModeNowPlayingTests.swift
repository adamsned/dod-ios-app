import DODAnalytics
import DODDomain
import DODSupport
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

@MainActor
@Suite("CookModeViewModel Now Playing") struct CookModeNowPlayingTests {

    /// AC-40.1 — Voice Mode is off every time Cook Mode is entered.
    @Test func snapshotIsStoppedWhenIdle() {
        let mock = MockSpeechSynthesizer()
        let viewModel = CookModeViewModelTests.makeViewModel(
            stepCount: 3,
            voiceReader: VoiceReader(synthesizer: mock)
        )

        #expect(viewModel.playbackState == .idle)
        let snapshot = viewModel.nowPlayingSnapshot
        #expect(snapshot.state == .stopped)
        #expect(snapshot.playbackRate == 0)
    }

    /// After setting voice mode, the snapshot should reflect playing state and correct title.
    @Test func snapshotIsPlayingAfterSetVoiceMode() {
        let mock = MockSpeechSynthesizer()
        let viewModel = CookModeViewModelTests.makeViewModel(
            stepCount: 3,
            voiceReader: VoiceReader(synthesizer: mock)
        )

        viewModel.setVoiceMode(true)

        #expect(viewModel.playbackState == .speaking)
        let snapshot = viewModel.nowPlayingSnapshot
        #expect(snapshot.state == .playing)
        #expect(snapshot.title == "Step 1 of 3")
        #expect(snapshot.subtitle == "Cook Mode Recipe")  // recipe title from test helper
    }

    /// After pausing voice, the snapshot should reflect paused state.
    @Test func snapshotIsPausedAfterPause() {
        let mock = MockSpeechSynthesizer()
        let viewModel = CookModeViewModelTests.makeViewModel(
            stepCount: 3,
            voiceReader: VoiceReader(synthesizer: mock)
        )

        viewModel.setVoiceMode(true)
        viewModel.pauseVoice()

        #expect(viewModel.playbackState == .paused)
        let snapshot = viewModel.nowPlayingSnapshot
        #expect(snapshot.state == .paused)
    }

    /// Toggle play/pause command should pause and then resume.
    @Test func togglePlayPauseCommandPausesThenResumes() {
        let mock = MockSpeechSynthesizer()
        let viewModel = CookModeViewModelTests.makeViewModel(
            stepCount: 3,
            voiceReader: VoiceReader(synthesizer: mock)
        )

        viewModel.setVoiceMode(true)
        #expect(viewModel.playbackState == .speaking)

        // First toggle should pause
        viewModel.handleNowPlayingCommand(.togglePlayPause)
        #expect(viewModel.playbackState == .paused)

        // Second toggle should resume
        viewModel.handleNowPlayingCommand(.togglePlayPause)
        #expect(viewModel.playbackState == .speaking)
    }

    /// Next step command should advance the current step index.
    @Test func nextStepCommandAdvances() {
        let mock = MockSpeechSynthesizer()
        let viewModel = CookModeViewModelTests.makeViewModel(
            stepCount: 3,
            voiceReader: VoiceReader(synthesizer: mock)
        )

        viewModel.setVoiceMode(true)
        #expect(viewModel.currentStepIndex == 0)

        viewModel.handleNowPlayingCommand(.nextStep)
        #expect(viewModel.currentStepIndex == 1)
    }
}

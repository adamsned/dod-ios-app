import Foundation
import Testing

@testable import DODFeatureRecipeDetail

@MainActor
@Suite("CookModeViewModel+Ask fallback") struct CookModeViewModelAskFallbackTests {

    @Test func emptyTranscriptSpeaksNothing() async {
        let mock = MockSpeechSynthesizer()
        let viewModel = CookModeViewModelTests.makeViewModel(
            stepCount: 2,
            voiceReader: VoiceReader(synthesizer: mock)
        )
        await viewModel.handleSpokenQuestion("   ", intelligence: nil)
        #expect(mock.spokenTexts.isEmpty)
    }

    @Test func unanswerableQuestionSpeaksSorry() async {
        let mock = MockSpeechSynthesizer()
        let viewModel = CookModeViewModelTests.makeViewModel(
            stepCount: 2,
            voiceReader: VoiceReader(synthesizer: mock)
        )
        await viewModel.handleSpokenQuestion("Why is the sky blue?", intelligence: nil)
        #expect(mock.spokenTexts == ["Sorry, I can't answer that right now."])
        #expect(viewModel.pausedUtteranceIsStale)
    }
}

import DODDomain
import Testing

@testable import DODFeatureRecipeDetail

@MainActor
@Suite("CookModeViewModel+Ask (DUT-1029)") struct CookModeViewModelAskTests {

    static func makeVM(mock: MockSpeechSynthesizer = MockSpeechSynthesizer()) -> CookModeViewModel {
        CookModeViewModelTests.makeViewModel(stepCount: 3, voiceReader: VoiceReader(synthesizer: mock))
    }

    @Test func whatsNextSpeaksTheFollowingStep() async {
        let mock = MockSpeechSynthesizer()
        let viewModel = Self.makeVM(mock: mock)
        await viewModel.handleSpokenQuestion("what's next", intelligence: nil)
        #expect(viewModel.voiceReader.isSpeaking)
        #expect(mock.spokenTexts == ["Next: Step 2 body."])
    }

    @Test func emptyTranscriptSpeaksNothing() async {
        let mock = MockSpeechSynthesizer()
        let viewModel = Self.makeVM(mock: mock)
        await viewModel.handleSpokenQuestion("   ", intelligence: nil)
        #expect(mock.spokenTexts.isEmpty)
    }
}

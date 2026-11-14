import DODDomain
import DODIntelligence
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

    @Test func repeatWhileReadingKeepsSpeakingWithoutStacking() async {
        let mock = MockSpeechSynthesizer()
        let viewModel = Self.makeVM(mock: mock)
        viewModel.setVoiceMode(true)
        await viewModel.handleSpokenQuestion("repeat that", intelligence: nil)
        #expect(viewModel.voiceReader.isSpeaking)
        #expect(mock.spokenTexts == ["Step 1 body.", "Step 1 body."])
    }

    @Test func openQuestionWithoutModelSaysSorry() async {
        let mock = MockSpeechSynthesizer()
        let viewModel = Self.makeVM(mock: mock)
        await viewModel.handleSpokenQuestion("Can I use a grill?", intelligence: nil)
        #expect(mock.spokenTexts == ["Sorry, I can't answer that right now."])
    }

    @Test func openQuestionSpeaksModelAnswer() async {
        let mock = MockSpeechSynthesizer()
        let viewModel = Self.makeVM(mock: mock)
        let fake = FakeIntelligenceService(answer: "Yes, chill it first.")
        await viewModel.handleSpokenQuestion("Can I make this ahead?", intelligence: fake)
        #expect(mock.spokenTexts == ["Yes, chill it first."])
    }

    @Test func unavailableModelSaysSorry() async {
        let mock = MockSpeechSynthesizer()
        let viewModel = Self.makeVM(mock: mock)
        let fake = FakeIntelligenceService(isAvailable: false)
        await viewModel.handleSpokenQuestion("Can I make this ahead?", intelligence: fake)
        #expect(mock.spokenTexts == ["Sorry, I can't answer that right now."])
    }
}

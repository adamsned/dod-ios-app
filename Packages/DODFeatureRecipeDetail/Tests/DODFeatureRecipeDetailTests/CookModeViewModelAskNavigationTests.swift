import Foundation
import Testing

@testable import DODFeatureRecipeDetail

@MainActor
@Suite("CookModeViewModel+Ask navigation") struct CookModeViewModelAskNavigationTests {

    private func make(_ mock: MockSpeechSynthesizer) -> CookModeViewModel {
        CookModeViewModelTests.makeViewModel(stepCount: 3, voiceReader: VoiceReader(synthesizer: mock))
    }

    @Test func nextStepSpeaksTheFollowingStep() async {
        let mock = MockSpeechSynthesizer()
        let viewModel = make(mock)
        await viewModel.handleSpokenQuestion("what's next", intelligence: nil)
        #expect(mock.spokenTexts == ["Next: Step 2 body."])
        #expect(viewModel.pausedUtteranceIsStale)
    }

    @Test func previousStepGoesBack() async {
        let mock = MockSpeechSynthesizer()
        let viewModel = make(mock)
        viewModel.advanceStep()
        await viewModel.handleSpokenQuestion("go back", intelligence: nil)
        #expect(viewModel.currentStepIndex == 0)
    }

    @Test func repeatReplaysCurrentStep() async {
        let mock = MockSpeechSynthesizer()
        let viewModel = make(mock)
        await viewModel.handleSpokenQuestion("repeat that", intelligence: nil)
        #expect(mock.spokenTexts == ["Step 1 body."])
    }
}

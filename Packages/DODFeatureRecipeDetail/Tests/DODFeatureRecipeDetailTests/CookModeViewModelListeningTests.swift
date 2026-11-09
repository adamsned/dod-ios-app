import Foundation
import Testing

@testable import DODFeatureRecipeDetail

@MainActor
@Suite("CookModeViewModel listening state (DUT-1029)") struct CookModeViewModelListeningTests {
    @Test func listeningStateStartsOff() {
        let viewModel = CookModeViewModelTests.makeViewModel(stepCount: 2)
        #expect(!viewModel.isListening)
        #expect(viewModel.liveTranscript.isEmpty)
        #expect(!viewModel.transcriber.isAvailable)
    }
}

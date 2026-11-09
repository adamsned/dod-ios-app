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

    @Test func endCookModeStopsTranscriberAndClearsListening() {
        let viewModel = CookModeViewModelTests.makeViewModel(stepCount: 2)
        let fake = FakeSpeechTranscriber()
        viewModel.transcriber = fake
        viewModel.isListening = true
        viewModel.listenTask = Task {}
        viewModel.endCookMode()
        #expect(fake.stopCallCount == 1)
        #expect(!viewModel.isListening)
        #expect(viewModel.listenTask == nil)
    }
}

@MainActor
final class FakeSpeechTranscriber: SpeechTranscribing {
    var isAvailable: Bool { true }
    private(set) var stopCallCount = 0
    func startListening() -> AsyncStream<String> { AsyncStream { $0.finish() } }
    func stopListening() { stopCallCount += 1 }
}

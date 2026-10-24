import Testing

@testable import DODFeatureRecipeDetail

@MainActor
@Suite("SpeechTranscribing (DUT-1029)") struct SpeechTranscribingTests {
    @Test func unavailableTranscriberIsUnavailableAndYieldsNothing() async {
        let transcriber = UnavailableSpeechTranscriber()
        #expect(!transcriber.isAvailable)
        var got: [String] = []
        for await text in transcriber.startListening() { got.append(text) }
        #expect(got.isEmpty)
    }
}

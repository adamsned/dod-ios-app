import AVFoundation
import DODSupport
import Foundation
import Testing

@testable import DODFeatureFeed

#if canImport(AVFoundation)

/// A conformer that implements ONLY `installedVoices()`, so it gets the protocol-extension defaults.
@MainActor
private final class DefaultsOnlyPreviewer: VoicePreviewing {
    func installedVoices() -> [VoiceDescriptor] { [] }
}

@MainActor
@Suite("SystemVoicePreviewer") struct SystemVoicePreviewerTests {

    @Test func protocolDefaultResolvedVoiceNameIsNil() {
        let previewer = DefaultsOnlyPreviewer()
        #expect(previewer.resolvedVoiceName(languageCode: "en-US") == nil)
        #expect(previewer.resolvedVoiceName(languageCode: nil) == nil)
    }

    @Test func protocolDefaultPreviewVoiceIsANoOp() {
        let previewer = DefaultsOnlyPreviewer()
        previewer.previewVoice(languageCode: "en-US")  // must not crash or speak
        #expect(previewer.installedVoices().isEmpty)
    }

    @Test func previewSampleLineIsTheRecipeStepSentence() {
        #expect(
            SystemVoicePreviewer.previewSampleLine
                == "Layer the noodles, then spread the meat mixture evenly over the top."
        )
    }

    @Test func systemPreviewerConformsToVoicePreviewing() {
        let previewer: any VoicePreviewing = SystemVoicePreviewer()
        #expect(previewer is SystemVoicePreviewer)
    }
}

#endif

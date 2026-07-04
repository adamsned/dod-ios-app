import Foundation
import Testing

@testable import DODFeatureRecipeDetail

#if canImport(AVFoundation)
import AVFoundation

/// DUT-273 — `SystemSpeechSynthesizer` used to re-enumerate + map + sort the
/// entire installed voice catalog (`AVSpeechSynthesisVoice.speechVoices()`) on
/// the main actor for EVERY spoken utterance, even though the resolved voice is
/// session-invariant (it changes only with `languageCode`; there's no user
/// voice preference — CL-279). In Voice Mode that hitched the main thread on
/// every step read. The fix memoizes the resolved voice per language. These
/// prove the expensive enumeration runs at most once per distinct language,
/// via a counting `voicesProvider` seam.
@MainActor
@Suite("SystemSpeechSynthesizer voice cache (DUT-273)")
struct SystemSpeechSynthesizerVoiceCacheTests {

    @Test func repeatedResolutionEnumeratesCatalogOnlyOnce() {
        let engine = SystemSpeechSynthesizer()
        var enumerationCount = 0
        engine.voicesProvider = {
            enumerationCount += 1
            return AVSpeechSynthesisVoice.speechVoices()
        }

        // Simulate advancing through many steps in one language (what Voice
        // Mode does — VoiceReader passes the same captured languageCode each
        // utterance).
        for _ in 0..<25 {
            _ = engine.resolveVoice(languageCode: "en")
        }

        // The catalog enumeration ran exactly once across all 25 resolutions.
        #expect(enumerationCount == 1)
    }

    @Test func resolvedVoiceIsStableAcrossRepeatedCalls() {
        let engine = SystemSpeechSynthesizer()
        let first = engine.resolveVoice(languageCode: "en")
        let second = engine.resolveVoice(languageCode: "en")
        // Memoized — same result object (or same nil) every time.
        #expect(first === second)
    }

    @Test func distinctLanguagesEachEnumerateOnce() {
        let engine = SystemSpeechSynthesizer()
        var enumerationCount = 0
        engine.voicesProvider = {
            enumerationCount += 1
            return AVSpeechSynthesisVoice.speechVoices()
        }

        _ = engine.resolveVoice(languageCode: "en")
        _ = engine.resolveVoice(languageCode: "en")  // cached
        _ = engine.resolveVoice(languageCode: "fr")  // new language → recompute
        _ = engine.resolveVoice(languageCode: "fr")  // cached
        _ = engine.resolveVoice(languageCode: nil)  // default key → recompute
        _ = engine.resolveVoice(languageCode: nil)  // cached

        // One enumeration per distinct language key (en, fr, <default>).
        #expect(enumerationCount == 3)
    }
}

#endif

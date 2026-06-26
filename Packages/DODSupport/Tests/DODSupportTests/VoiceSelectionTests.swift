import DODSupport
import Foundation
import Testing

/// L1 coverage for ``VoiceSelector`` — the Cook Mode Voice Mode quality
/// selection engine (US-40 / AC-40.9, T-720; CL-279 / DUT-329 — one
/// auto-selected voice, no user preference). Pure value-type logic, zero
/// AVFoundation dependency, so it runs on the macOS `swift test` slice (CL-109).
@Suite("VoiceSelector (US-40 / DUT-329)") struct VoiceSelectionTests {

    private func voice(_ id: String, _ lang: String, _ quality: VoiceQuality) -> VoiceDescriptor {
        VoiceDescriptor(identifier: id, languageCode: lang, quality: quality)
    }

    // MARK: - The robotic-fix contract

    @Test func picksEnhancedOverCompact() {
        // The core "sounds like a robot" fix: with both a compact and an
        // enhanced voice installed for en-US, reach past the compact tier.
        let catalog = [
            voice("compact", "en-US", .default),
            voice("enhanced", "en-US", .enhanced),
        ]
        #expect(VoiceSelector.bestVoiceIdentifier(from: catalog, languageCode: "en-US") == "enhanced")
    }

    @Test func picksPremiumOverEnhancedOverDefault() {
        let catalog = [
            voice("compact", "en-US", .default),
            voice("enhanced", "en-US", .enhanced),
            voice("premium", "en-US", .premium),
        ]
        #expect(VoiceSelector.bestVoiceIdentifier(from: catalog, languageCode: "en-US") == "premium")
    }

    @Test func naturalBeatsRoboticAcrossLocaleTieBreak() {
        // Natural-first dominates the exact-locale tie-break: an enhanced en-GB
        // voice beats a compact en-US voice even for an en-US request.
        let catalog = [
            voice("us.compact", "en-US", .default),
            voice("gb.enhanced", "en-GB", .enhanced),
        ]
        #expect(VoiceSelector.bestVoiceIdentifier(from: catalog, languageCode: "en-US") == "gb.enhanced")
    }

    // MARK: - Default voice is Samantha (DUT-330)

    @Test func defaultsToSamanthaAmongCompactVoices() {
        // Stock device: only compact en-US voices. The default is Samantha, not
        // whatever sorts first by identifier (here "Albert" would, without the
        // Samantha tie-break).
        let catalog = [
            voice("com.apple.voice.compact.en-US.Albert", "en-US", .default),
            voice("com.apple.voice.compact.en-US.Samantha", "en-US", .default),
            voice("com.apple.voice.compact.en-US.Fred", "en-US", .default),
        ]
        #expect(
            VoiceSelector.bestVoiceIdentifier(from: catalog, languageCode: "en-US")
                == "com.apple.voice.compact.en-US.Samantha"
        )
    }

    @Test func prefersSamanthaAmongEqualNaturalVoices() {
        // Two enhanced voices: Samantha wins the tie-break (without it, "Daniel"
        // sorts first by identifier).
        let catalog = [
            voice("enhanced.Daniel", "en-US", .enhanced),
            voice("enhanced.Samantha", "en-US", .enhanced),
        ]
        #expect(VoiceSelector.bestVoiceIdentifier(from: catalog, languageCode: "en-US") == "enhanced.Samantha")
    }

    @Test func naturalNonSamanthaStillBeatsCompactSamantha() {
        // Samantha is only a tie-break BELOW quality: a downloaded enhanced
        // (natural) voice still wins over the compact Samantha, so the DUT-327
        // "don't sound like a robot" fix is preserved.
        let catalog = [
            voice("compact.Samantha", "en-US", .default),
            voice("enhanced.Daniel", "en-US", .enhanced),
        ]
        #expect(VoiceSelector.bestVoiceIdentifier(from: catalog, languageCode: "en-US") == "enhanced.Daniel")
    }

    @Test func samanthaMatchIsCaseInsensitiveSubstring() {
        let catalog = [
            voice("com.apple.voice.compact.en-US.SAMANTHA", "en-US", .default),
            voice("com.apple.voice.compact.en-US.Aaron", "en-US", .default),
        ]
        #expect(
            VoiceSelector.bestVoiceIdentifier(from: catalog, languageCode: "en-US")
                == "com.apple.voice.compact.en-US.SAMANTHA"
        )
    }

    // MARK: - Language matching

    @Test func matchesByLanguageFamilyPrefix() {
        let catalog = [voice("enUS.enhanced", "en-US", .enhanced)]
        #expect(VoiceSelector.bestVoiceIdentifier(from: catalog, languageCode: "en") == "enUS.enhanced")
    }

    @Test func prefersExactLocaleOverPrefixAsTieBreak() {
        // Two same-quality en voices; the exact-tag match wins the tie-break.
        let catalog = [
            voice("enGB.enhanced", "en-GB", .enhanced),
            voice("enUS.enhanced", "en-US", .enhanced),
        ]
        #expect(VoiceSelector.bestVoiceIdentifier(from: catalog, languageCode: "en-US") == "enUS.enhanced")
    }

    @Test func returnsNilWhenNoLanguageMatch() {
        let catalog = [voice("fr.enhanced", "fr-FR", .enhanced)]
        #expect(VoiceSelector.bestVoiceIdentifier(from: catalog, languageCode: "en-US") == nil)
    }

    @Test func nilLanguageCodeMatchesEveryVoice() {
        let catalog = [
            voice("fr.compact", "fr-FR", .default),
            voice("fr.enhanced", "fr-FR", .enhanced),
        ]
        #expect(VoiceSelector.bestVoiceIdentifier(from: catalog, languageCode: nil) == "fr.enhanced")
    }

    @Test func emptyCatalogReturnsNil() {
        #expect(VoiceSelector.bestVoiceIdentifier(from: [], languageCode: "en-US") == nil)
    }

    @Test func selectionIsDeterministicAcrossEqualCandidates() {
        let voiceA = voice("aaa", "en-US", .enhanced)
        let voiceB = voice("bbb", "en-US", .enhanced)
        let forward = VoiceSelector.bestVoiceIdentifier(from: [voiceA, voiceB], languageCode: "en-US")
        let reversed = VoiceSelector.bestVoiceIdentifier(from: [voiceB, voiceA], languageCode: "en-US")
        #expect(forward == "aaa")
        #expect(reversed == "aaa")
    }

    // MARK: - bestAvailableQuality / hasNaturalVoice (the "install a better voice" signal)

    @Test func bestAvailableQualityReturnsHighestTier() {
        let catalog = [
            voice("compact", "en-US", .default),
            voice("premium", "en-US", .premium),
        ]
        #expect(VoiceSelector.bestAvailableQuality(forLanguage: "en-US", from: catalog) == .premium)
    }

    @Test func bestAvailableQualityIsDefaultWhenOnlyCompactInstalled() {
        let catalog = [voice("compact", "en-US", .default)]
        #expect(VoiceSelector.bestAvailableQuality(forLanguage: "en-US", from: catalog) == .default)
    }

    @Test func bestAvailableQualityIsNilWhenNoLanguageMatch() {
        let catalog = [voice("fr.enhanced", "fr-FR", .enhanced)]
        #expect(VoiceSelector.bestAvailableQuality(forLanguage: "en-US", from: catalog) == nil)
    }

    @Test func hasNaturalVoiceIsFalseWhenOnlyCompactInstalled() {
        let catalog = [voice("compact", "en-US", .default)]
        #expect(!VoiceSelector.hasNaturalVoice(forLanguage: "en-US", in: catalog))
    }

    @Test func hasNaturalVoiceIsTrueWhenEnhancedInstalled() {
        let catalog = [
            voice("compact", "en-US", .default),
            voice("enhanced", "en-US", .enhanced),
        ]
        #expect(VoiceSelector.hasNaturalVoice(forLanguage: "en-US", in: catalog))
    }

    @Test func hasNaturalVoiceIsFalseWhenNoLanguageMatch() {
        let catalog = [voice("fr.premium", "fr-FR", .premium)]
        #expect(!VoiceSelector.hasNaturalVoice(forLanguage: "en-US", in: catalog))
    }

    @Test func hasNaturalVoiceIsFalseOnEmptyCatalog() {
        #expect(!VoiceSelector.hasNaturalVoice(forLanguage: "en-US", in: []))
    }

    // MARK: - Siri voices are excluded (DUT-331)

    @Test func skipsSiriVoiceForAUsableEnhancedOne() {
        // A Siri voice resolves + reports premium, but AVSpeechSynthesizer won't
        // speak with it in a 3rd-party app (falls back to robotic). With a real
        // downloaded Enhanced voice also installed, pick the Enhanced one.
        let catalog = [
            voice("com.apple.voice.compact.en-US.Samantha", "en-US", .default),
            voice("com.apple.voice.enhanced.en-US.Evan", "en-US", .enhanced),
            voice("com.apple.ttsbundle.siri_Nicky_en-US_premium", "en-US", .premium),
        ]
        #expect(
            VoiceSelector.bestVoiceIdentifier(from: catalog, languageCode: "en-US")
                == "com.apple.voice.enhanced.en-US.Evan"
        )
    }

    @Test func fallsBackToCompactWhenOnlyNaturalIsSiri() {
        // If the only non-compact voice is a Siri voice, it must NOT be picked;
        // fall back to a usable compact voice instead of the unusable Siri one.
        let catalog = [
            voice("com.apple.voice.compact.en-US.Samantha", "en-US", .default),
            voice("com.apple.ttsbundle.siri_Nicky_en-US_premium", "en-US", .premium),
        ]
        #expect(
            VoiceSelector.bestVoiceIdentifier(from: catalog, languageCode: "en-US")
                == "com.apple.voice.compact.en-US.Samantha"
        )
    }

    @Test func hasNaturalVoiceIgnoresSiriVoices() {
        // The "install a better voice" gate must treat a Siri-only catalog as
        // having NO usable natural voice, so the prompt still surfaces.
        let catalog = [
            voice("com.apple.voice.compact.en-US.Samantha", "en-US", .default),
            voice("com.apple.ttsbundle.siri_Nicky_en-US_premium", "en-US", .premium),
        ]
        #expect(!VoiceSelector.hasNaturalVoice(forLanguage: "en-US", in: catalog))
    }
}

import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// L1 coverage for ``VoiceSelector`` — the Cook Mode Voice Mode quality +
/// gender-selection engine (US-40 / AC-40.9..AC-40.11, T-720). Pure value-type
/// logic, zero AVFoundation dependency, so it runs on the macOS `swift test`
/// slice (CL-109).
@Suite("VoiceSelector (US-40 / T-720)") struct VoiceSelectionTests {

    // Convenience builders keep the fixtures readable.
    private func voice(
        _ id: String,
        _ lang: String,
        _ gender: VoiceGender,
        _ quality: VoiceQuality
    ) -> VoiceDescriptor {
        VoiceDescriptor(identifier: id, languageCode: lang, gender: gender, quality: quality)
    }

    // MARK: - The robotic-fix contract

    @Test func picksEnhancedOverCompactForTheSameGender() {
        // The core "sounds like a robot" fix: when both a compact (default)
        // and an enhanced female voice are installed for en-US, the selector
        // must reach past the compact tier to the enhanced one — the exact
        // case `AVSpeechSynthesisVoice(language:)` got wrong.
        let catalog = [
            voice("compact.Samantha", "en-US", .female, .default),
            voice("enhanced.Samantha", "en-US", .female, .enhanced),
        ]
        let chosen = VoiceSelector.bestVoiceIdentifier(
            from: catalog,
            languageCode: "en-US",
            preference: .default
        )
        #expect(chosen == "enhanced.Samantha")
    }

    @Test func picksPremiumOverEnhancedOverDefault() {
        let catalog = [
            voice("compact", "en-US", .female, .default),
            voice("enhanced", "en-US", .female, .enhanced),
            voice("premium", "en-US", .female, .premium),
        ]
        let chosen = VoiceSelector.bestVoiceIdentifier(
            from: catalog,
            languageCode: "en-US",
            preference: .default
        )
        #expect(chosen == "premium")
    }

    // MARK: - Gender preference

    @Test func prefersRequestedGenderOverOppositeGender() {
        let catalog = [
            voice("male.enhanced", "en-US", .male, .enhanced),
            voice("female.enhanced", "en-US", .female, .enhanced),
        ]
        let male = VoiceSelector.bestVoiceIdentifier(
            from: catalog,
            languageCode: "en-US",
            preference: VoicePreference(gender: .male)
        )
        #expect(male == "male.enhanced")

        let female = VoiceSelector.bestVoiceIdentifier(
            from: catalog,
            languageCode: "en-US",
            preference: VoicePreference(gender: .female)
        )
        #expect(female == "female.enhanced")
    }

    @Test func genderIsPrimaryOverQuality() {
        // A compact voice of the requested gender beats a premium voice of the
        // opposite gender — the explicit gender choice is honored. (The
        // default-female experience still upgrades because en-US ships
        // enhanced female voices; this only bites when the requested gender
        // has only compact voices installed — Phase b's download deep-link is
        // the escape hatch. CL-109 documents the trade-off.)
        let catalog = [
            voice("female.compact", "en-US", .female, .default),
            voice("male.premium", "en-US", .male, .premium),
        ]
        let chosen = VoiceSelector.bestVoiceIdentifier(
            from: catalog,
            languageCode: "en-US",
            preference: VoicePreference(gender: .female)
        )
        #expect(chosen == "female.compact")
    }

    @Test func unspecifiedGenderBeatsOppositeGenderWhenNoMatch() {
        // No female voice installed: an unspecified-gender enhanced voice
        // (rank 1) is preferred over an opposite-gender (male) premium voice
        // (rank 2) — better a neutral natural voice than a wrong-gender one.
        let catalog = [
            voice("neutral.enhanced", "en-US", .unspecified, .enhanced),
            voice("male.premium", "en-US", .male, .premium),
        ]
        let chosen = VoiceSelector.bestVoiceIdentifier(
            from: catalog,
            languageCode: "en-US",
            preference: VoicePreference(gender: .female)
        )
        #expect(chosen == "neutral.enhanced")
    }

    // MARK: - Language matching

    @Test func matchesByLanguageFamilyPrefix() {
        // A request for "en" matches an "en-US" voice (same language family).
        let catalog = [voice("enUS.enhanced", "en-US", .female, .enhanced)]
        let chosen = VoiceSelector.bestVoiceIdentifier(
            from: catalog,
            languageCode: "en",
            preference: .default
        )
        #expect(chosen == "enUS.enhanced")
    }

    @Test func prefersExactLocaleOverPrefixAsTieBreak() {
        // Two same-gender same-quality en voices; the one whose tag exactly
        // matches the request wins the tie-break.
        let catalog = [
            voice("enGB.enhanced", "en-GB", .female, .enhanced),
            voice("enUS.enhanced", "en-US", .female, .enhanced),
        ]
        let chosen = VoiceSelector.bestVoiceIdentifier(
            from: catalog,
            languageCode: "en-US",
            preference: .default
        )
        #expect(chosen == "enUS.enhanced")
    }

    @Test func returnsNilWhenNoLanguageMatch() {
        // A French-only catalog against an English request → nil, so the
        // caller falls back to the platform default (degrades as before).
        let catalog = [voice("fr.enhanced", "fr-FR", .female, .enhanced)]
        let chosen = VoiceSelector.bestVoiceIdentifier(
            from: catalog,
            languageCode: "en-US",
            preference: .default
        )
        #expect(chosen == nil)
    }

    @Test func nilLanguageCodeMatchesEveryVoice() {
        let catalog = [
            voice("fr.compact", "fr-FR", .female, .default),
            voice("fr.enhanced", "fr-FR", .female, .enhanced),
        ]
        let chosen = VoiceSelector.bestVoiceIdentifier(
            from: catalog,
            languageCode: nil,
            preference: .default
        )
        #expect(chosen == "fr.enhanced")
    }

    @Test func emptyCatalogReturnsNil() {
        let chosen = VoiceSelector.bestVoiceIdentifier(
            from: [],
            languageCode: "en-US",
            preference: .default
        )
        #expect(chosen == nil)
    }

    @Test func selectionIsDeterministicAcrossEqualCandidates() {
        // Two voices identical on every ranked axis — the identifier
        // tie-break makes the choice stable regardless of catalog order.
        let voiceA = voice("aaa", "en-US", .female, .enhanced)
        let voiceB = voice("bbb", "en-US", .female, .enhanced)
        let forward = VoiceSelector.bestVoiceIdentifier(
            from: [voiceA, voiceB],
            languageCode: "en-US",
            preference: .default
        )
        let reversed = VoiceSelector.bestVoiceIdentifier(
            from: [voiceB, voiceA],
            languageCode: "en-US",
            preference: .default
        )
        #expect(forward == "aaa")
        #expect(reversed == "aaa")
    }
}

import DODSupport
import Foundation
import Testing

/// L1 coverage for the DUT-327 additions to ``VoiceSelector`` — the explicit
/// voice pick + the Settings picker's `voicesForLanguage` list. Split out of
/// `VoiceSelectionTests` so each `@Suite` struct body stays under the SwiftLint
/// `type_body_length` cap.
@Suite("VoiceSelector explicit pick (DUT-327)") struct VoiceSelectionExplicitPickTests {

    private func voice(
        _ id: String,
        _ lang: String,
        _ gender: VoiceGender,
        _ quality: VoiceQuality
    ) -> VoiceDescriptor {
        VoiceDescriptor(identifier: id, languageCode: lang, gender: gender, quality: quality)
    }

    // MARK: - Explicit voice pick

    @Test func explicitVoiceIdentifierWinsOutright() {
        // The user "wired in" a specific voice — return it verbatim, bypassing
        // gender + quality ranking entirely (even picking a compact voice on
        // purpose, or one of the non-preferred gender).
        let catalog = [
            voice("female.enhanced", "en-US", .female, .enhanced),
            voice("male.compact", "en-US", .male, .default),
        ]
        let chosen = VoiceSelector.bestVoiceIdentifier(
            from: catalog,
            languageCode: "en-US",
            preference: VoicePreference(gender: .female, voiceIdentifier: "male.compact")
        )
        #expect(chosen == "male.compact")
    }

    @Test func explicitPickFallsBackToAutomaticWhenUninstalled() {
        // A pinned voice the user later deleted is gone from the catalog → fall
        // through to Automatic (never to silence).
        let catalog = [voice("female.enhanced", "en-US", .female, .enhanced)]
        let chosen = VoiceSelector.bestVoiceIdentifier(
            from: catalog,
            languageCode: "en-US",
            preference: VoicePreference(gender: .female, voiceIdentifier: "deleted.voice")
        )
        #expect(chosen == "female.enhanced")
    }

    // MARK: - voicesForLanguage (the Settings picker's list)

    @Test func voicesForLanguageIsNaturalFirstThenByName() {
        let catalog = [
            voice("zeta.compact", "en-US", .male, .default),
            voice("alpha.enhanced", "en-US", .female, .enhanced),
            voice("beta.premium", "en-US", .female, .premium),
            voice("fr.enhanced", "fr-FR", .female, .enhanced),
        ]
        let ids = VoiceSelector.voicesForLanguage("en-US", in: catalog).map(\.identifier)
        // premium → enhanced → compact for en; the fr voice is excluded.
        #expect(ids == ["beta.premium", "alpha.enhanced", "zeta.compact"])
    }

    @Test func voicesForLanguageExcludesOtherLanguageFamilies() {
        let catalog = [
            voice("en.enhanced", "en-US", .female, .enhanced),
            voice("fr.premium", "fr-FR", .female, .premium),
        ]
        let ids = VoiceSelector.voicesForLanguage("en", in: catalog).map(\.identifier)
        #expect(ids == ["en.enhanced"])
    }
}

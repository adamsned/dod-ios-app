import DODSupport
import Foundation
import Testing

@testable import DODFeatureFeed

/// L1 coverage for the Cook Mode voice-gender preference exposed through
/// ``SettingsViewModel`` (T-721, the Phase-b Settings picker for US-40's
/// voice-quality engine). Verifies the view-model is a faithful, isolated
/// front-end over ``VoicePreferenceStore`` — the same store the recipe-detail
/// read-aloud engine reads — so flipping the picker actually changes the
/// voice the next time Cook Mode resolves one.
///
/// Spec trace: US-40 AC-40.10 (gender-primary selection honors the stored
/// preference) / AC-40.11 (canonical key `dod.voice.preferredGenderV1`,
/// default `.female`, unknown value falls back to `.female`).
@MainActor
@Suite("SettingsViewModel voice picker (T-721)") struct SettingsViewModelVoiceTests {

    /// Fresh, per-test `UserDefaults` suite so a write in one test never
    /// leaks into another (mirrors ``SettingsViewModelTests``).
    static func isolatedDefaults() -> UserDefaults {
        let suiteName = "SettingsViewModelVoiceTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test func defaultGenderIsFemaleOnFreshDefaults() async throws {
        let viewModel = SettingsViewModel(defaults: Self.isolatedDefaults())
        // AC-40.11 — unset key resolves to `.female` (the platform-default
        // voice, en-US Samantha), so the picker opens on a sensible value.
        #expect(viewModel.voiceGender == .female)
    }

    @Test func settingGenderPersistsToCanonicalKey() async throws {
        let defaults = Self.isolatedDefaults()
        let viewModel = SettingsViewModel(defaults: defaults)

        viewModel.voiceGender = .male
        #expect(viewModel.voiceGender == .male)
        // Round-trip through the EXACT key the read-aloud engine reads
        // (AC-40.11) — the store persists the lowercase case name.
        #expect(defaults.string(forKey: VoicePreferenceStore.genderKey) == "male")

        viewModel.voiceGender = .unspecified
        #expect(defaults.string(forKey: VoicePreferenceStore.genderKey) == "unspecified")
    }

    @Test func newViewModelReadsBackPersistedGender() async throws {
        let defaults = Self.isolatedDefaults()
        SettingsViewModel(defaults: defaults).voiceGender = .male

        // A fresh view-model over the same suite observes the persisted
        // choice — the picker reflects prior selection across launches.
        #expect(SettingsViewModel(defaults: defaults).voiceGender == .male)
    }

    @Test func unknownStoredValueFallsBackToFemale() async throws {
        let defaults = Self.isolatedDefaults()
        // A value the store doesn't recognize (forward-compat / corruption)
        // must degrade to `.female`, never crash or surface a phantom case.
        defaults.set("klingon", forKey: VoicePreferenceStore.genderKey)
        #expect(SettingsViewModel(defaults: defaults).voiceGender == .female)
    }

    @Test func everyGenderRoundTrips() async throws {
        for gender in VoiceGender.allCases {
            let defaults = Self.isolatedDefaults()
            let viewModel = SettingsViewModel(defaults: defaults)
            viewModel.voiceGender = gender
            #expect(viewModel.voiceGender == gender)
            #expect(SettingsViewModel(defaults: defaults).voiceGender == gender)
        }
    }
}

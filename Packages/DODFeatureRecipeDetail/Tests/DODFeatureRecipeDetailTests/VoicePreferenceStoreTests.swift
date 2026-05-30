import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// L1 coverage for ``VoicePreferenceStore`` (US-40 / AC-40.11, T-720). Uses an
/// isolated `UserDefaults` suite per test so the device defaults are never
/// touched (mirrors the `GuestIdentityStore` test isolation pattern).
@Suite("VoicePreferenceStore (US-40 / T-720)") struct VoicePreferenceStoreTests {

    /// A throwaway defaults suite scoped to one test, cleared on creation.
    /// `UserDefaults(suiteName:)` only returns nil for a name colliding with
    /// the main bundle identifier or the global domain — the `test.voice.`
    /// prefix can't, so the fallback to `.standard` is unreachable but keeps
    /// the helper force-unwrap-free.
    private func isolatedDefaults(_ name: String) -> UserDefaults {
        let suiteName = "test.voice.\(name)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test func defaultsToFemaleWhenUnset() {
        let store = VoicePreferenceStore(defaults: isolatedDefaults("unset"))
        #expect(store.preference() == VoicePreference(gender: .female))
    }

    @Test func roundTripsMale() {
        let store = VoicePreferenceStore(defaults: isolatedDefaults("male"))
        store.setGender(.male)
        #expect(store.preference() == VoicePreference(gender: .male))
    }

    @Test func roundTripsFemale() {
        let store = VoicePreferenceStore(defaults: isolatedDefaults("female"))
        store.setGender(.female)
        #expect(store.preference() == VoicePreference(gender: .female))
    }

    @Test func roundTripsUnspecified() {
        let store = VoicePreferenceStore(defaults: isolatedDefaults("unspecified"))
        store.setGender(.unspecified)
        #expect(store.preference() == VoicePreference(gender: .unspecified))
    }

    @Test func overwritePersistsLatestValue() {
        let store = VoicePreferenceStore(defaults: isolatedDefaults("overwrite"))
        store.setGender(.male)
        store.setGender(.female)
        #expect(store.preference() == VoicePreference(gender: .female))
    }

    @Test func unknownStoredValueFallsBackToDefault() {
        let defaults = isolatedDefaults("garbage")
        defaults.set("banana", forKey: VoicePreferenceStore.genderKey)
        let store = VoicePreferenceStore(defaults: defaults)
        #expect(store.preference() == .default)
    }

    @Test func canonicalKeyMatchesSpec() {
        // AC-40.11 pins the exact key string the Phase-b Settings UI binds to.
        #expect(VoicePreferenceStore.genderKey == "dod.voice.preferredGenderV1")
    }
}

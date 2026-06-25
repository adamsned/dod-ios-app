import DODSupport
import Foundation
import Testing

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

    // MARK: - Explicit voice pick (DUT-327)

    @Test func voiceIdentifierDefaultsToNil() {
        let store = VoicePreferenceStore(defaults: isolatedDefaults("id-unset"))
        #expect(store.preference().voiceIdentifier == nil)
    }

    @Test func roundTripsVoiceIdentifier() {
        let store = VoicePreferenceStore(defaults: isolatedDefaults("id-roundtrip"))
        store.setVoiceIdentifier("com.apple.voice.enhanced.en-US.Evan")
        #expect(store.preference().voiceIdentifier == "com.apple.voice.enhanced.en-US.Evan")
    }

    @Test func clearingVoiceIdentifierReturnsToAutomatic() {
        let store = VoicePreferenceStore(defaults: isolatedDefaults("id-clear"))
        store.setVoiceIdentifier("com.apple.voice.premium.en-US.Zoe")
        store.setVoiceIdentifier(nil)
        #expect(store.preference().voiceIdentifier == nil)
    }

    @Test func genderAndIdentifierCoexist() {
        // The explicit pick and the gender tie-break persist independently.
        let store = VoicePreferenceStore(defaults: isolatedDefaults("id-and-gender"))
        store.setGender(.male)
        store.setVoiceIdentifier("voice.x")
        let pref = store.preference()
        #expect(pref.gender == .male)
        #expect(pref.voiceIdentifier == "voice.x")
    }

    @Test func identifierKeyMatchesSpec() {
        #expect(VoicePreferenceStore.identifierKey == "dod.voice.preferredIdentifierV1")
    }
}

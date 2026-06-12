import Foundation
import Observation
import Testing

@testable import DODFeatureFeed

/// L1 coverage for T-756 / CL-153 (DUT-62) — the three Settings picker
/// preferences (`appearance`, `temperaturePreference`, `voiceGender`) are
/// now `@Observable` STORED properties, so mutating them emits an
/// observation change and SwiftUI re-renders the picker (the label) + the
/// Settings sheet's `.preferredColorScheme`.
///
/// These tests directly pin the fix: `withObservationTracking` registers a
/// read of the property, then a mutation must fire `onChange`. On the
/// pre-T-756 computed-over-store implementation the read registered no
/// observable access (the value came from `UserDefaults` /
/// `VoicePreferenceStore`, not a tracked stored property), so `onChange`
/// never fired — these tests would fail. They pass only once the
/// properties are observable.
///
/// Spec trace: US-36 AC-36.2; US-40 AC-40.10; DUT-47; CL-153.
@MainActor
@Suite("SettingsViewModel observation (T-756 / CL-153)")
struct SettingsViewModelObservationTests {

    /// Reference box so the `@Sendable` `onChange` closure can flip a flag
    /// (it can't capture a mutable local `var`).
    private final class Flag: @unchecked Sendable { var fired = false }

    static func isolatedDefaults() -> UserDefaults {
        let suiteName = "SettingsViewModelObservationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test func appearanceMutationTriggersObservation() {
        let viewModel = SettingsViewModel(defaults: Self.isolatedDefaults())
        let flag = Flag()
        withObservationTracking {
            _ = viewModel.appearance
        } onChange: {
            flag.fired = true
        }
        // Mutate to a different value so the change is unambiguous.
        viewModel.appearance = (viewModel.appearance == .dark) ? .light : .dark
        #expect(flag.fired, "Mutating `appearance` must emit an @Observable change")
    }

    @Test func temperaturePreferenceMutationTriggersObservation() {
        let viewModel = SettingsViewModel(defaults: Self.isolatedDefaults())
        let flag = Flag()
        withObservationTracking {
            _ = viewModel.temperaturePreference
        } onChange: {
            flag.fired = true
        }
        viewModel.temperaturePreference = (viewModel.temperaturePreference == .celsius) ? .fahrenheit : .celsius
        #expect(flag.fired, "Mutating `temperaturePreference` must emit an @Observable change")
    }

    @Test func voiceGenderMutationTriggersObservation() {
        let viewModel = SettingsViewModel(defaults: Self.isolatedDefaults())
        let flag = Flag()
        withObservationTracking {
            _ = viewModel.voiceGender
        } onChange: {
            flag.fired = true
        }
        viewModel.voiceGender = (viewModel.voiceGender == .male) ? .female : .male
        #expect(flag.fired, "Mutating `voiceGender` must emit an @Observable change")
    }

    /// The observable conversion must NOT break the persistence contract:
    /// `didSet` still writes through to the backing store, and a fresh
    /// view-model seeds the persisted value back in `init`.
    @Test func observableConversionPreservesPersistence() {
        let defaults = Self.isolatedDefaults()
        let first = SettingsViewModel(defaults: defaults)
        first.appearance = .dark
        first.temperaturePreference = .celsius
        first.voiceGender = .male

        let second = SettingsViewModel(defaults: defaults)
        #expect(second.appearance == .dark)
        #expect(second.temperaturePreference == .celsius)
        #expect(second.voiceGender == .male)
    }
}

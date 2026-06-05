import Foundation
import Testing

@testable import DODFeatureFeed

/// L1 unit coverage for the recipe-step temperature unit preference
/// (DUT-47, temperature half). Mirrors the appearance / share-format
/// round-trip contract: the picker persists through the injected
/// `UserDefaults`, a fresh view-model reads the persisted value back, an
/// unknown raw value falls back to the safe default, and flipping it does
/// not disturb the other Settings preferences.
///
/// Default is ``TemperaturePreference/recipeDefault`` — "show as written",
/// no conversion — so an untouched install renders instruction
/// temperatures exactly as the recipe author wrote them.
///
/// Spec trace: DUT-47 (temperature half).
@MainActor
@Suite("Settings temperature preference (DUT-47)") struct SettingsTemperaturePreferenceTests {

    @Test func defaultsToRecipeDefaultWhenAbsent() async throws {
        let defaults = Self.isolatedDefaults()
        let viewModel = SettingsViewModel(defaults: defaults)

        // Absent key → "Recipe default" (no conversion applied).
        #expect(viewModel.temperaturePreference == .recipeDefault)
        #expect(TemperaturePreference.fromDefaults(defaults) == .recipeDefault)
    }

    @Test func roundTripsAllThreeCases() async throws {
        let defaults = Self.isolatedDefaults()
        let viewModel = SettingsViewModel(defaults: defaults)

        for value in TemperaturePreference.allCases {
            viewModel.temperaturePreference = value
            #expect(viewModel.temperaturePreference == value)
            #expect(
                defaults.string(forKey: SettingsViewModel.temperaturePreferenceKey) == value.rawValue
            )
            // The view-model-bypass read path (used by Recipe Detail's
            // @AppStorage gate) honors the same value.
            #expect(TemperaturePreference.fromDefaults(defaults) == value)
        }
    }

    @Test func unknownRawValueFallsBackToRecipeDefault() async throws {
        let defaults = Self.isolatedDefaults()
        defaults.set("kelvin", forKey: SettingsViewModel.temperaturePreferenceKey)
        // A future rename / unknown string must NOT crash — defensive
        // fallback keeps the user at "show as written".
        #expect(TemperaturePreference.fromDefaults(defaults) == .recipeDefault)
    }

    @Test func newViewModelInstanceReadsBackPersistedValue() async throws {
        let defaults = Self.isolatedDefaults()
        let first = SettingsViewModel(defaults: defaults)
        first.temperaturePreference = .celsius

        let second = SettingsViewModel(defaults: defaults)
        #expect(second.temperaturePreference == .celsius)
    }

    @Test func persistsIndependentlyOfOtherPreferences() async throws {
        let defaults = Self.isolatedDefaults()
        let viewModel = SettingsViewModel(defaults: defaults)

        viewModel.appearance = .dark
        viewModel.temperaturePreference = .fahrenheit
        viewModel.useMetricUnits = true

        // Flipping temperature doesn't disturb the neighbors.
        viewModel.temperaturePreference = .celsius

        #expect(viewModel.temperaturePreference == .celsius)
        #expect(viewModel.appearance == .dark)
        #expect(viewModel.useMetricUnits == true)
    }

    /// Maps each preference to the converter unit it drives. "Recipe
    /// default" maps to `nil` — the Recipe Detail gate treats `nil` as
    /// "don't run the converter".
    @Test func targetUnitMapping() async throws {
        #expect(TemperaturePreference.recipeDefault.targetUnit == nil)
        #expect(TemperaturePreference.fahrenheit.targetUnit == .fahrenheit)
        #expect(TemperaturePreference.celsius.targetUnit == .celsius)
    }

    /// Per-test isolated UserDefaults suite so the standard defaults stay
    /// clean across the L1 run. Mirrors `SettingsViewModelTests`.
    static func isolatedDefaults() -> UserDefaults {
        let suiteName = "SettingsTemperaturePreferenceTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

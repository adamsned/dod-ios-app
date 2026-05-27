import Foundation
import Testing

@testable import DODFeatureFeed

/// L1 unit coverage for ``SettingsViewModel``'s UserDefaults round-trip.
///
/// Spec trace: US-32 AC-32.4 (toggle persists to UserDefaults).
@MainActor
@Suite("SettingsViewModel (T-550)") struct SettingsViewModelTests {

    @Test func toggleMetricUnitsPersistsToInjectedDefaults() async throws {
        let defaults = Self.isolatedDefaults()
        let viewModel = SettingsViewModel(defaults: defaults)

        // Initial value defaults to false on a fresh UserDefaults suite —
        // `bool(forKey:)` returns `false` for a missing key, which is the
        // documented imperial-default behavior for v1.
        #expect(viewModel.useMetricUnits == false)

        viewModel.useMetricUnits = true
        #expect(viewModel.useMetricUnits == true)
        // Round-trip through the underlying defaults — the value must be
        // observable from a sibling reader (e.g., the T-551 follow-up's
        // ingredient-rendering path).
        #expect(defaults.bool(forKey: SettingsViewModel.useMetricUnitsKey) == true)

        viewModel.useMetricUnits = false
        #expect(defaults.bool(forKey: SettingsViewModel.useMetricUnitsKey) == false)
    }

    @Test func newViewModelInstanceReadsBackPersistedValue() async throws {
        let defaults = Self.isolatedDefaults()
        let first = SettingsViewModel(defaults: defaults)
        first.useMetricUnits = true

        // A fresh view-model instance reading the same suite picks up the
        // persisted flag — proves the read path is not cached on the
        // instance and survives app restarts.
        let second = SettingsViewModel(defaults: defaults)
        #expect(second.useMetricUnits == true)
    }

    @Test func versionFooterReadsFromBundleInfoDictionary() async throws {
        // Default (Bundle.main) is environment-dependent; just assert the
        // shape matches `v<version> (<build>)`.
        let footer = SettingsViewModel.versionFooter()
        #expect(footer.hasPrefix("v"))
        #expect(footer.contains("("))
        #expect(footer.hasSuffix(")"))
    }

    /// Per-test isolated UserDefaults suite so the standard defaults
    /// stay clean across the L1 run. Mirrors `RecentSearchesTests`.
    static func isolatedDefaults() -> UserDefaults {
        let suiteName = "SettingsViewModelTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

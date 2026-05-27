import Foundation
import Testing

@testable import DODFeatureFeed

/// L1 unit coverage for ``SettingsViewModel``'s UserDefaults round-trip,
/// the cache-clear snackbar formatter, and the new round-7 preferences
/// (Notifications, Appearance, Share Format, Telemetry).
///
/// Spec trace: US-32 AC-32.4 (metric units); US-36 AC-36.1..AC-36.7
/// (notifications, appearance, share format, telemetry, cache-clear
/// snackbar, persistence).
@MainActor
@Suite("SettingsViewModel (T-550 + T-630)") struct SettingsViewModelTests {

    // MARK: - US-32 (T-550) — metric units

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

    // MARK: - US-36 AC-36.1 — Notifications toggle

    @Test func notificationsEnabledPersistsToInjectedDefaults() async throws {
        let defaults = Self.isolatedDefaults()
        let viewModel = SettingsViewModel(defaults: defaults)

        // AC-36.1 — default OFF.
        #expect(viewModel.notificationsEnabled == false)
        viewModel.notificationsEnabled = true
        #expect(defaults.bool(forKey: SettingsViewModel.notificationsEnabledKey) == true)

        // Round-trip across instances — proves the persistence contract
        // T-631 follow-up will read against.
        let next = SettingsViewModel(defaults: defaults)
        #expect(next.notificationsEnabled == true)
    }

    // MARK: - US-36 AC-36.2 — Appearance picker

    @Test func appearancePreferenceRoundTripsAllThreeCases() async throws {
        let defaults = Self.isolatedDefaults()
        let viewModel = SettingsViewModel(defaults: defaults)

        // Default — Match System when the key is absent.
        #expect(viewModel.appearance == .system)

        for value in AppearancePreference.allCases {
            viewModel.appearance = value
            #expect(viewModel.appearance == value)
            #expect(defaults.string(forKey: SettingsViewModel.appearancePreferenceKey) == value.rawValue)
            // The view-model-bypass read path (used by RootView) honors
            // the same value.
            #expect(AppearancePreference.fromDefaults(defaults) == value)
        }
    }

    @Test func appearancePreferenceUnknownRawValueFallsBackToSystem() async throws {
        let defaults = Self.isolatedDefaults()
        defaults.set("midnight", forKey: SettingsViewModel.appearancePreferenceKey)
        // A future rename / unknown string must NOT crash — defensive
        // fallback keeps the user at Match System.
        #expect(AppearancePreference.fromDefaults(defaults) == .system)
    }

    // MARK: - US-36 AC-36.3 — Share format picker

    @Test func shareFormatPreferenceRoundTripsBothCases() async throws {
        let defaults = Self.isolatedDefaults()
        let viewModel = SettingsViewModel(defaults: defaults)

        // Default — link only, preserves AC-6.2's existing share contract.
        #expect(viewModel.shareFormat == .linkOnly)

        for value in ShareFormatPreference.allCases {
            viewModel.shareFormat = value
            #expect(viewModel.shareFormat == value)
            #expect(defaults.string(forKey: SettingsViewModel.shareFormatPreferenceKey) == value.rawValue)
            #expect(ShareFormatPreference.fromDefaults(defaults) == value)
        }
    }

    @Test func shareFormatPreferenceUnknownRawValueFallsBackToLinkOnly() async throws {
        let defaults = Self.isolatedDefaults()
        defaults.set("essay", forKey: SettingsViewModel.shareFormatPreferenceKey)
        #expect(ShareFormatPreference.fromDefaults(defaults) == .linkOnly)
    }

    // MARK: - US-36 AC-36.5 — Telemetry toggle

    @Test func telemetryEnabledDefaultsToTrueWhenAbsent() async throws {
        let defaults = Self.isolatedDefaults()
        let viewModel = SettingsViewModel(defaults: defaults)

        // AC-36.5: defaults ON (matches constitution §9's opt-out posture).
        #expect(viewModel.telemetryEnabled == true)
        #expect(SettingsViewModel.telemetryEnabled(in: defaults) == true)
    }

    @Test func telemetryEnabledRespectsExplicitFalse() async throws {
        let defaults = Self.isolatedDefaults()
        let viewModel = SettingsViewModel(defaults: defaults)

        viewModel.telemetryEnabled = false
        #expect(viewModel.telemetryEnabled == false)
        // The TelemetryDeckTransport reads via the same default-aware
        // helper — pin that helper returns false too.
        #expect(SettingsViewModel.telemetryEnabled(in: defaults) == false)

        viewModel.telemetryEnabled = true
        #expect(viewModel.telemetryEnabled == true)
        #expect(SettingsViewModel.telemetryEnabled(in: defaults) == true)
    }

    // MARK: - US-36 AC-36.4 — Cache-clear snackbar formatter

    @Test func cacheClearMessageRendersMBAndZeroCase() async throws {
        // Zero-byte branch: snackbar surfaces "already clear" so the
        // tap isn't a silent no-op.
        #expect(SettingsViewModel.cacheClearMessage(freedBytes: 0) == "Cache was already clear.")

        // Non-zero — formatter renders 1 decimal MB.
        let oneMB = 1024 * 1024
        #expect(SettingsViewModel.cacheClearMessage(freedBytes: oneMB).contains("1.0 MB"))
        // 47.2 MB exercises the rounding behavior.
        let fortySevenPointTwoMB = Int(47.2 * 1024.0 * 1024.0)
        #expect(SettingsViewModel.cacheClearMessage(freedBytes: fortySevenPointTwoMB).contains("47.2 MB"))
        #expect(SettingsViewModel.cacheClearMessage(freedBytes: fortySevenPointTwoMB).hasPrefix("Freed "))
    }

    @Test func clearImageCacheRoutesThroughClosureAndSetsSnackbar() async throws {
        let defaults = Self.isolatedDefaults()
        let viewModel = SettingsViewModel(defaults: defaults)

        let bytes = 5 * 1024 * 1024  // 5 MB
        await viewModel.clearImageCache(onClear: { bytes })
        #expect(viewModel.snackbarMessage?.contains("5.0 MB") == true)

        // Dismiss clears the message so the snackbar disappears on tap.
        viewModel.dismissSnackbar()
        #expect(viewModel.snackbarMessage == nil)
    }

    @Test func clearImageCacheZeroBytesShowsAlreadyClearMessage() async throws {
        let viewModel = SettingsViewModel(defaults: Self.isolatedDefaults())
        await viewModel.clearImageCache(onClear: { 0 })
        #expect(viewModel.snackbarMessage == "Cache was already clear.")
    }

    @Test func clearImageCacheErrorPathSurfacesRetryCopy() async throws {
        struct FakeError: Error {}
        let viewModel = SettingsViewModel(defaults: Self.isolatedDefaults())
        await viewModel.clearImageCache(onClear: { throw FakeError() })
        #expect(viewModel.snackbarMessage == "Couldn't clear cache — try again.")
    }

    // MARK: - US-36 AC-36.7 — Independent persistence

    @Test func eachPreferenceRoundTripsIndependently() async throws {
        let defaults = Self.isolatedDefaults()
        let viewModel = SettingsViewModel(defaults: defaults)

        viewModel.useMetricUnits = true
        viewModel.notificationsEnabled = true
        viewModel.appearance = .dark
        viewModel.shareFormat = .linkAndText
        viewModel.telemetryEnabled = false

        // Flipping one doesn't disturb the others — pin the independence
        // contract AC-36.7 promises.
        viewModel.useMetricUnits = false

        #expect(viewModel.useMetricUnits == false)
        #expect(viewModel.notificationsEnabled == true)
        #expect(viewModel.appearance == .dark)
        #expect(viewModel.shareFormat == .linkAndText)
        #expect(viewModel.telemetryEnabled == false)
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

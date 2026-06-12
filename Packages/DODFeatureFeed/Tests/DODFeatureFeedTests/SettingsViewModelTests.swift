import DODPersistence
import Foundation
import Testing
import os

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

    // MARK: - US-41 AC-41.3 — iCloud Sync toggle (T-703)

    @Test func togglingOnCallsRecreateContainerAfterFlagWrite() async throws {
        let defaults = Self.isolatedDefaults()
        let recorder = RecordingSettingsDependencies(defaults: defaults)
        let viewModel = SettingsViewModel(defaults: defaults, dependencies: recorder)

        // Toggle starts OFF per the canonical default. T-759 / CL-156 —
        // the toggle flips DIRECTLY via `setCloudSyncEnabled` (no
        // confirmation popup); `?.value` awaits the dependency write Task.
        #expect(viewModel.isCloudSyncEnabled == false)
        await viewModel.setCloudSyncEnabled(true)?.value

        // Dependency saw the flag-write call (and the flag landed in
        // UserDefaults before the container rebuild fired — order
        // matters because `RecipeStore.recreateContainerAfterOptInChange`
        // reads UserDefaults during construction).
        #expect(recorder.invocations == [true])
        #expect(recorder.flagWasWrittenBeforeRebuild == true)
        #expect(viewModel.isCloudSyncEnabled == true)
    }

    @Test func togglingOffCallsRecreateContainerAfterFlagWrite() async throws {
        let defaults = Self.isolatedDefaults()
        // Seed the flag ON so the OFF flip exercises the opposite path.
        defaults.set(true, forKey: RecipeStore.cloudKitSyncOptInKey)
        let recorder = RecordingSettingsDependencies(defaults: defaults)
        let viewModel = SettingsViewModel(defaults: defaults, dependencies: recorder)

        #expect(viewModel.isCloudSyncEnabled == true)
        await viewModel.setCloudSyncEnabled(false)?.value

        #expect(recorder.invocations == [false])
        #expect(recorder.flagWasWrittenBeforeRebuild == true)
        #expect(viewModel.isCloudSyncEnabled == false)
    }

    @Test func cloudSyncStatusTextDefaultsToIdle() async throws {
        // T-705 will replace this with the real `CloudKitSyncStatus`
        // enum's `displayString`. Today it returns "Idle" because the
        // sync state machine isn't wired yet — pin the placeholder so a
        // future T-705 refactor that drops the row by accident shows up
        // as a test failure rather than a silent regression.
        let viewModel = SettingsViewModel(defaults: Self.isolatedDefaults())
        #expect(viewModel.cloudSyncStatusText == "Idle")
    }

    @Test func flippingSyncMarksRelaunchPendingInSublabel() async throws {
        // Round-12 backlog bug: SwiftData builds the container once per
        // process, so a flipped toggle only engages on the next cold
        // launch. The sublabel must say so instead of silently staying "Idle".
        let viewModel = SettingsViewModel(defaults: Self.isolatedDefaults())
        #expect(viewModel.cloudSyncPendingRelaunch == false)
        #expect(viewModel.cloudSyncStatusText == "Idle")

        await viewModel.setCloudSyncEnabled(true)?.value

        #expect(viewModel.cloudSyncPendingRelaunch == true)
        #expect(viewModel.cloudSyncStatusText == "Relaunch DOD to apply")
    }

    @Test func initialStateReadsCurrentUserDefaultsValue() async throws {
        // The user may have flipped the flag via T-704's first-launch
        // sheet before ever opening Settings; the view-model's cached
        // state must mirror whatever the canonical key reports at
        // construction.
        let defaults = Self.isolatedDefaults()
        defaults.set(true, forKey: RecipeStore.cloudKitSyncOptInKey)
        let recorder = RecordingSettingsDependencies(defaults: defaults)

        let viewModel = SettingsViewModel(defaults: defaults, dependencies: recorder)
        #expect(viewModel.isCloudSyncEnabled == true)

        // Flip the flag in defaults and rebuild — proves the read path
        // is dependency-driven, not cached on a stale defaults snapshot.
        defaults.set(false, forKey: RecipeStore.cloudKitSyncOptInKey)
        let next = SettingsViewModel(defaults: defaults, dependencies: recorder)
        #expect(next.isCloudSyncEnabled == false)
    }

    @Test func settingSyncToTheCurrentValueIsANoOp() async throws {
        // T-759 / CL-156 — `setCloudSyncEnabled` no-ops on an unchanged
        // value (returns nil, never touches the dependency or persistence),
        // so a spurious binding fire can't double-write or relaunch-flag.
        let defaults = Self.isolatedDefaults()
        let recorder = RecordingSettingsDependencies(defaults: defaults)
        let viewModel = SettingsViewModel(defaults: defaults, dependencies: recorder)

        #expect(viewModel.isCloudSyncEnabled == false)
        let task = viewModel.setCloudSyncEnabled(false)  // already OFF
        #expect(task == nil)
        #expect(viewModel.isCloudSyncEnabled == false)
        #expect(viewModel.cloudSyncPendingRelaunch == false)
        #expect(recorder.invocations.isEmpty)
        #expect(defaults.bool(forKey: RecipeStore.cloudKitSyncOptInKey) == false)
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

// MARK: - Recording double for SettingsDependencies (US-41 / T-703)

/// L1 double for ``SettingsDependencies``. Records every
/// `setCloudSyncOptIn(_:)` call AND pins the UserDefaults flag value
/// observed at the moment the rebuild would have fired, so the suite
/// can assert the "flag written → container rebuilt" ordering contract
/// from T-702's `recreateContainerAfterOptInChange()` seam.
///
/// State is stored behind a `OSAllocatedUnfairLock` so the recorder is
/// `Sendable` without `@MainActor` isolation — the protocol's
/// `Sendable` requirement is the one that matters here, and `withLock`
/// is async-safe (unlike `NSLock.lock()` which the compiler rejects
/// from async contexts).
final class RecordingSettingsDependencies: SettingsDependencies, @unchecked Sendable {
    private struct State {
        var invocations: [Bool] = []
        var flagWasWrittenBeforeRebuild = false
    }

    private let defaults: UserDefaults
    private let state = OSAllocatedUnfairLock<State>(initialState: State())

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    var invocations: [Bool] {
        state.withLock { $0.invocations }
    }

    var flagWasWrittenBeforeRebuild: Bool {
        state.withLock { $0.flagWasWrittenBeforeRebuild }
    }

    func setCloudSyncOptIn(_ enabled: Bool) async {
        // Mirror the live wiring's two-step contract — write the flag,
        // then "rebuild" (a no-op here; the assertion is that the
        // observed flag value matches `enabled` at the moment the
        // rebuild would fire).
        defaults.set(enabled, forKey: RecipeStore.cloudKitSyncOptInKey)
        let observed = defaults.bool(forKey: RecipeStore.cloudKitSyncOptInKey)
        state.withLock { value in
            value.invocations.append(enabled)
            value.flagWasWrittenBeforeRebuild = (observed == enabled)
        }
    }

    func cloudSyncOptInValue() -> Bool {
        defaults.bool(forKey: RecipeStore.cloudKitSyncOptInKey)
    }
}

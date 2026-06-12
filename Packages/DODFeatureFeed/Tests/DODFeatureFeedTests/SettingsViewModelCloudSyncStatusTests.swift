import DODPersistence
import Foundation
import Testing

@testable import DODFeatureFeed

/// L1 coverage for the DUT-6 (cause B) minimal sync-status surface on
/// ``SettingsViewModel`` — the status the App-target
/// `NSPersistentCloudKitContainer` mirror observer pushes into the Settings
/// → iCloud Sync row's status sublabel, and the relaunch-pending override.
///
/// Split into its own file (the source-side `SettingsViewModel +
/// SettingsViewModel+CloudSync.swift` partitioning rule) so
/// `SettingsViewModelTests.swift` stays under the SwiftLint 400-line
/// file_length cap.
@MainActor
@Suite("SettingsViewModel iCloud Sync status (DUT-6)")
struct SettingsViewModelCloudSyncStatusTests {

    @Test func cloudSyncStatusTextMapsObservedMirrorStatus() async throws {
        // The status sublabel reflects the coarse mirror status pushed in by
        // the App-target observer. Pin each mapping so a future refactor that
        // drops the surface fails here.
        let viewModel = SettingsViewModel(defaults: Self.isolatedDefaults())

        // Default (no event yet) reads the reserved "Idle" placeholder.
        #expect(viewModel.cloudSyncStatusText == "Idle")

        viewModel.updateCloudSyncStatus(.syncing)
        #expect(viewModel.cloudSyncStatusText == "Syncing…")

        viewModel.updateCloudSyncStatus(.error("Did not find any record types"))
        #expect(viewModel.cloudSyncStatusText == "Sync error")

        viewModel.updateCloudSyncStatus(.idle)
        #expect(viewModel.cloudSyncStatusText == "Idle")
    }

    @Test func relaunchPendingOverridesObservedMirrorStatus() async throws {
        // Once a flip is pending, the relaunch copy wins regardless of what
        // the (stale, pre-relaunch) mirror reports — the live status only
        // means something after the container is rebuilt at next launch.
        let viewModel = SettingsViewModel(defaults: Self.isolatedDefaults())
        viewModel.updateCloudSyncStatus(.syncing)
        #expect(viewModel.cloudSyncStatusText == "Syncing…")

        await viewModel.setCloudSyncEnabled(true)?.value

        #expect(viewModel.cloudSyncPendingRelaunch == true)
        #expect(viewModel.cloudSyncStatusText == "Relaunch DOD to apply")
    }

    @Test func refreshPullsStatusFromDependency() async throws {
        // `refreshCloudSyncStatus()` (called when the Settings screen
        // appears) pulls the latest status from the dependency seam.
        let stub = StubStatusDependencies(status: .syncing)
        let viewModel = SettingsViewModel(defaults: Self.isolatedDefaults(), dependencies: stub)

        #expect(viewModel.cloudSyncStatusText == "Idle")
        viewModel.refreshCloudSyncStatus()
        #expect(viewModel.cloudSyncStatusText == "Syncing…")
    }

    @Test func refreshIsSkippedWhileRelaunchPending() async throws {
        // A pending relaunch keeps the relaunch copy even if the (stale)
        // dependency would report a live status.
        let stub = StubStatusDependencies(status: .idle)
        let viewModel = SettingsViewModel(defaults: Self.isolatedDefaults(), dependencies: stub)

        await viewModel.setCloudSyncEnabled(true)?.value
        #expect(viewModel.cloudSyncStatusText == "Relaunch DOD to apply")

        viewModel.refreshCloudSyncStatus()
        #expect(viewModel.cloudSyncStatusText == "Relaunch DOD to apply")
    }

    static func isolatedDefaults() -> UserDefaults {
        let suiteName = "SettingsViewModelCloudSyncStatusTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

/// Minimal ``SettingsDependencies`` double that returns a fixed sync status
/// so the refresh path can be pinned without the App-target mirror observer.
/// Holds no `UserDefaults` — the status tests only read the sublabel, so the
/// opt-in seam methods are inert here.
private struct StubStatusDependencies: SettingsDependencies {
    let status: CloudKitSyncStatus

    func setCloudSyncOptIn(_ enabled: Bool) async {}

    func cloudSyncOptInValue() -> Bool { false }

    func currentCloudSyncStatus() -> CloudKitSyncStatus { status }
}

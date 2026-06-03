import DODFeatureFeed
import DODPersistence
import Foundation

// MARK: - US-41 / AC-41.3 (T-703) live Settings wiring

/// Production conformance to ``SettingsDependencies``. Holds a
/// `@Sendable` closure that persists the opt-in flag (DUT-6 — there is no
/// mid-session container rebuild any more; the flag is the launch-time
/// source of truth) and a status provider that reads the App-target
/// CloudKit mirror observer's latest coarse status (cause B).
///
/// Extracted from `AppDependencies.swift` so that file stays under the
/// SwiftLint 400-line `file_length` cap after the Phase b (T-740)
/// `ProfilePhotoStore` wiring was added at the composition root.
///
/// Spec trace: US-41 AC-41.3, AC-41.4; CL-89; DUT-6.
struct LiveSettingsDependencies: SettingsDependencies {

    typealias FlagWrite = @Sendable (Bool) async -> Void
    typealias StatusProvider = @Sendable () -> CloudKitSyncStatus

    let flagWrite: FlagWrite
    let statusProvider: StatusProvider

    init(
        flagWrite: @escaping FlagWrite,
        statusProvider: @escaping StatusProvider = { .off }
    ) {
        self.flagWrite = flagWrite
        self.statusProvider = statusProvider
    }

    func setCloudSyncOptIn(_ enabled: Bool) async {
        await flagWrite(enabled)
    }

    func cloudSyncOptInValue() -> Bool {
        RecipeStore.cloudKitSyncOptIn()
    }

    func currentCloudSyncStatus() -> CloudKitSyncStatus {
        statusProvider()
    }
}

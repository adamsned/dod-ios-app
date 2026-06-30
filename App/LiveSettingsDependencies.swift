import DODFeatureFeed
import DODPersistence
import DODSupport
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
    // DUT-417 — profile-stats data loaders + the journal edit, injected from
    // the composition root so this struct stays a thin `RecipeStore` adapter.
    typealias CookLogsLoad = @Sendable () async throws -> [CookLogEntry]
    typealias CountLoad = @Sendable () async throws -> Int
    typealias CookLogWrite = @Sendable (CookLogEntry) async throws -> Void

    let flagWrite: FlagWrite
    let statusProvider: StatusProvider
    let cookLogsLoad: CookLogsLoad
    let savedCountLoad: CountLoad
    let ratingCountLoad: CountLoad
    let cookLogWrite: CookLogWrite

    init(
        flagWrite: @escaping FlagWrite,
        statusProvider: @escaping StatusProvider = { .off },
        cookLogsLoad: @escaping CookLogsLoad = { [] },
        savedCountLoad: @escaping CountLoad = { 0 },
        ratingCountLoad: @escaping CountLoad = { 0 },
        cookLogWrite: @escaping CookLogWrite = { _ in }
    ) {
        self.flagWrite = flagWrite
        self.statusProvider = statusProvider
        self.cookLogsLoad = cookLogsLoad
        self.savedCountLoad = savedCountLoad
        self.ratingCountLoad = ratingCountLoad
        self.cookLogWrite = cookLogWrite
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

    // MARK: - Profile stats (DUT-417)

    func cookLogs() async throws -> [CookLogEntry] { try await cookLogsLoad() }
    func savedRecipeCount() async throws -> Int { try await savedCountLoad() }
    func userRatingCount() async throws -> Int { try await ratingCountLoad() }
    func updateCookLog(_ entry: CookLogEntry) async throws { try await cookLogWrite(entry) }
}

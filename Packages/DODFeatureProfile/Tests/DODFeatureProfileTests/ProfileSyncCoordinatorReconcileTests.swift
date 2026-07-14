import DODSupport
import Foundation
import Testing

@testable import DODFeatureProfile

/// DUT-943 Scope A — integration coverage for ``ProfileSyncCoordinator``'s
/// cloud -> local reconcile direction (`reconcileFromRemote()`). Split from
/// `ProfileSyncCoordinatorTests` (which covers the `ProfileStoring`
/// passthrough + local -> cloud mirror) to keep both files under the
/// SwiftLint `type_body_length` cap; shares the same small
/// fixture-construction pattern.
@Suite("ProfileSyncCoordinator reconcile (DUT-943 Scope A)")
struct ProfileSyncCoordinatorReconcileTests {

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "ProfileSyncCoordinatorReconcileTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makeCoordinator(
        wrapping store: InMemoryProfileStore = InMemoryProfileStore(),
        sessionStore: InMemoryAppleAuthSessionStore = InMemoryAppleAuthSessionStore(),
        syncStore: InMemoryProfileSyncStore = InMemoryProfileSyncStore(),
        isICloudSyncEnabled: @escaping @Sendable () -> Bool,
        defaults: UserDefaults
    ) -> ProfileSyncCoordinator {
        let accessors = ProfileSyncCoordinator.standardDefaultsAccessors(defaults: defaults)
        #if canImport(UIKit)
        return ProfileSyncCoordinator(
            wrapping: store,
            photoStore: nil,
            sessionStore: sessionStore,
            syncStore: syncStore,
            isICloudSyncEnabled: isICloudSyncEnabled,
            readLocalUpdatedAt: accessors.read,
            writeLocalUpdatedAt: accessors.write
        )
        #else
        return ProfileSyncCoordinator(
            wrapping: store,
            sessionStore: sessionStore,
            syncStore: syncStore,
            isICloudSyncEnabled: isICloudSyncEnabled,
            readLocalUpdatedAt: accessors.read,
            writeLocalUpdatedAt: accessors.write
        )
        #endif
    }

    @Test func reconcileAppliesANewerRemoteRowToTheLocalProfile() async throws {
        let wrapped = InMemoryProfileStore(
            initial: UserProfile(id: UUID(), displayName: "Stale Name", email: "stale@example.com")
        )
        let sessionStore = InMemoryAppleAuthSessionStore(
            initial: AppleAuthSession(userIdentifier: "user-1")
        )
        let syncStore = InMemoryProfileSyncStore(seed: [
            SyncedProfileRecord(
                ownerUserIdentifier: "user-1",
                displayName: "Fresh Name",
                email: "fresh@example.com",
                photoData: nil,
                updatedAt: Date(timeIntervalSince1970: 1_000)
            )
        ])
        let defaults = isolatedDefaults()
        // Local edit timestamp is OLDER than the remote row, so remote wins.
        defaults.set(
            Date(timeIntervalSince1970: 500).timeIntervalSince1970,
            forKey: ProfileSyncCoordinator.localUpdatedAtKey
        )
        let coordinator = makeCoordinator(
            wrapping: wrapped,
            sessionStore: sessionStore,
            syncStore: syncStore,
            isICloudSyncEnabled: { true },
            defaults: defaults
        )

        await coordinator.reconcileFromRemote()

        let loaded = await coordinator.load()
        #expect(loaded?.displayName == "Fresh Name")
        #expect(loaded?.email == "fresh@example.com")
    }

    @Test func reconcileIgnoresAnOlderRemoteRow() async throws {
        let localProfile = UserProfile(id: UUID(), displayName: "Local Name", email: "local@example.com")
        let wrapped = InMemoryProfileStore(initial: localProfile)
        let sessionStore = InMemoryAppleAuthSessionStore(
            initial: AppleAuthSession(userIdentifier: "user-1")
        )
        let syncStore = InMemoryProfileSyncStore(seed: [
            SyncedProfileRecord(
                ownerUserIdentifier: "user-1",
                displayName: "Old Remote Name",
                email: "old@example.com",
                photoData: nil,
                updatedAt: Date(timeIntervalSince1970: 100)
            )
        ])
        let defaults = isolatedDefaults()
        // Local edit is NEWER than the remote row, so local must win.
        defaults.set(
            Date(timeIntervalSince1970: 900).timeIntervalSince1970,
            forKey: ProfileSyncCoordinator.localUpdatedAtKey
        )
        let coordinator = makeCoordinator(
            wrapping: wrapped,
            sessionStore: sessionStore,
            syncStore: syncStore,
            isICloudSyncEnabled: { true },
            defaults: defaults
        )

        await coordinator.reconcileFromRemote()

        let loaded = await coordinator.load()
        #expect(loaded?.displayName == "Local Name", "An older remote row must not overwrite a newer local edit")
    }

    @Test func reconcileIgnoresARowForADifferentUser() async throws {
        let localProfile = UserProfile(id: UUID(), displayName: "My Name", email: "me@example.com")
        let wrapped = InMemoryProfileStore(initial: localProfile)
        let sessionStore = InMemoryAppleAuthSessionStore(
            initial: AppleAuthSession(userIdentifier: "user-1")
        )
        let syncStore = InMemoryProfileSyncStore(seed: [
            SyncedProfileRecord(
                ownerUserIdentifier: "user-2",  // a DIFFERENT signed-in user's row
                displayName: "Someone Else",
                email: "someone@example.com",
                photoData: nil,
                updatedAt: Date(timeIntervalSince1970: 999_999)
            )
        ])
        let coordinator = makeCoordinator(
            wrapping: wrapped,
            sessionStore: sessionStore,
            syncStore: syncStore,
            isICloudSyncEnabled: { true },
            defaults: isolatedDefaults()
        )

        await coordinator.reconcileFromRemote()

        let loaded = await coordinator.load()
        #expect(loaded?.displayName == "My Name", "A different user's row must never bleed onto this device (DUT-371)")
    }

    @Test func reconcileDoesNothingWhenSyncIsOff() async throws {
        let localProfile = UserProfile(id: UUID(), displayName: "My Name", email: "me@example.com")
        let wrapped = InMemoryProfileStore(initial: localProfile)
        let sessionStore = InMemoryAppleAuthSessionStore(
            initial: AppleAuthSession(userIdentifier: "user-1")
        )
        let syncStore = InMemoryProfileSyncStore(seed: [
            SyncedProfileRecord(
                ownerUserIdentifier: "user-1",
                displayName: "Fresh Name",
                email: "fresh@example.com",
                photoData: nil,
                updatedAt: Date(timeIntervalSince1970: 999_999)
            )
        ])
        let coordinator = makeCoordinator(
            wrapping: wrapped,
            sessionStore: sessionStore,
            syncStore: syncStore,
            isICloudSyncEnabled: { false },
            defaults: isolatedDefaults()
        )

        await coordinator.reconcileFromRemote()

        let loaded = await coordinator.load()
        #expect(loaded?.displayName == "My Name", "Sync-off must never apply a remote row, even a winning one")
    }

    @Test func reconcileDoesNothingWhenSignedOut() async throws {
        let localProfile = UserProfile(id: UUID(), displayName: "My Name", email: "me@example.com")
        let wrapped = InMemoryProfileStore(initial: localProfile)
        let syncStore = InMemoryProfileSyncStore()
        let coordinator = makeCoordinator(
            wrapping: wrapped,
            sessionStore: InMemoryAppleAuthSessionStore(),  // no session
            syncStore: syncStore,
            isICloudSyncEnabled: { true },
            defaults: isolatedDefaults()
        )

        await coordinator.reconcileFromRemote()

        let loaded = await coordinator.load()
        #expect(loaded?.displayName == "My Name")
    }

    @Test func reconcileWithNoSyncedRowIsANoOp() async throws {
        let localProfile = UserProfile(id: UUID(), displayName: "My Name", email: "me@example.com")
        let wrapped = InMemoryProfileStore(initial: localProfile)
        let sessionStore = InMemoryAppleAuthSessionStore(
            initial: AppleAuthSession(userIdentifier: "user-1")
        )
        let coordinator = makeCoordinator(
            wrapping: wrapped,
            sessionStore: sessionStore,
            syncStore: InMemoryProfileSyncStore(),  // empty
            isICloudSyncEnabled: { true },
            defaults: isolatedDefaults()
        )

        await coordinator.reconcileFromRemote()

        let loaded = await coordinator.load()
        #expect(loaded?.displayName == "My Name")
    }
}

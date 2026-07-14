import DODSupport
import Foundation
import Testing

@testable import DODFeatureProfile

/// DUT-943 Scope A — integration coverage for ``ProfileSyncCoordinator``'s
/// `ProfileStoring` passthrough + the local -> cloud mirror-on-save, against
/// in-memory fakes (`InMemoryProfileStore`, `InMemoryProfileSyncStore`,
/// `InMemoryAppleAuthSessionStore`). The cloud -> local reconcile direction
/// is covered by the sibling `ProfileSyncCoordinatorReconcileTests` (split
/// out to keep both files under the SwiftLint `type_body_length` cap); both
/// exercise the wiring around the pure ``ProfileSyncReconciler`` decisions
/// already pinned by `ProfileSyncReconcilerTests`.
///
/// Runs with `photoStore: nil` throughout (the coordinator's documented
/// graceful-degradation path, same as `ProfileEditView`'s own `photoStore:
/// nil` default) so this suite compiles and runs on BOTH iOS and the macOS
/// `swift test` L1 slice — the photo-bytes path itself is UIKit-only and
/// covered structurally by `ProfilePhotoStoreTests`.
@Suite("ProfileSyncCoordinator (DUT-943 Scope A)")
struct ProfileSyncCoordinatorTests {

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "ProfileSyncCoordinatorTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makeCoordinator(
        wrapping store: InMemoryProfileStore = InMemoryProfileStore(),
        sessionStore: InMemoryAppleAuthSessionStore = InMemoryAppleAuthSessionStore(),
        syncStore: InMemoryProfileSyncStore = InMemoryProfileSyncStore(),
        isICloudSyncEnabled: @escaping @Sendable () -> Bool,
        defaults: UserDefaults,
        now: @escaping @Sendable () -> Date = { .now }
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
            writeLocalUpdatedAt: accessors.write,
            now: now
        )
        #else
        return ProfileSyncCoordinator(
            wrapping: store,
            sessionStore: sessionStore,
            syncStore: syncStore,
            isICloudSyncEnabled: isICloudSyncEnabled,
            readLocalUpdatedAt: accessors.read,
            writeLocalUpdatedAt: accessors.write,
            now: now
        )
        #endif
    }

    // MARK: - Passthrough (sync off / signed out) behaves exactly like today

    @Test func loadSaveClearPassThroughToTheWrappedStoreWhenSyncOff() async throws {
        let wrapped = InMemoryProfileStore()
        let coordinator = makeCoordinator(
            wrapping: wrapped,
            isICloudSyncEnabled: { false },
            defaults: isolatedDefaults()
        )
        let profile = UserProfile(id: UUID(), displayName: "Ned", email: "ned@example.com")

        try await coordinator.save(profile)
        let loaded = await coordinator.load()
        #expect(loaded == profile)
        #expect(await wrapped.load() == profile, "The wrapped store must have the same profile")

        try await coordinator.clear()
        #expect(await coordinator.load() == nil)
    }

    @Test func syncOffNeverMirrorsEvenWhenSignedIn() async throws {
        let sessionStore = InMemoryAppleAuthSessionStore(
            initial: AppleAuthSession(userIdentifier: "user-1")
        )
        let syncStore = InMemoryProfileSyncStore()
        let coordinator = makeCoordinator(
            sessionStore: sessionStore,
            syncStore: syncStore,
            isICloudSyncEnabled: { false },
            defaults: isolatedDefaults()
        )
        try await coordinator.save(UserProfile(id: UUID(), displayName: "Ned", email: "ned@example.com"))

        let mirrored = try await syncStore.fetch(ownerUserIdentifier: "user-1")
        #expect(mirrored == nil, "Sync-off save must never write a SyncedProfile row")
    }

    @Test func signedOutNeverMirrorsEvenWhenSyncOn() async throws {
        let syncStore = InMemoryProfileSyncStore()
        let coordinator = makeCoordinator(
            sessionStore: InMemoryAppleAuthSessionStore(),  // no session
            syncStore: syncStore,
            isICloudSyncEnabled: { true },
            defaults: isolatedDefaults()
        )
        try await coordinator.save(UserProfile(id: UUID(), displayName: "Ned", email: "ned@example.com"))

        let count = await syncStore.upsertedRecords.count
        #expect(count == 0, "Signed-out save must never write a SyncedProfile row")
    }

    // MARK: - Local -> Cloud mirror

    @Test func syncOnAndSignedInMirrorsTheSavedProfile() async throws {
        let sessionStore = InMemoryAppleAuthSessionStore(
            initial: AppleAuthSession(userIdentifier: "user-1")
        )
        let syncStore = InMemoryProfileSyncStore()
        let fixedNow = Date(timeIntervalSince1970: 500)
        let coordinator = makeCoordinator(
            sessionStore: sessionStore,
            syncStore: syncStore,
            isICloudSyncEnabled: { true },
            defaults: isolatedDefaults(),
            now: { fixedNow }
        )
        let profile = UserProfile(id: UUID(), displayName: "Ned Adams", email: "ned@example.com")

        try await coordinator.save(profile)

        let mirrored = try await syncStore.fetch(ownerUserIdentifier: "user-1")
        #expect(mirrored?.displayName == "Ned Adams")
        #expect(mirrored?.email == "ned@example.com")
        #expect(mirrored?.ownerUserIdentifier == "user-1")
        #expect(mirrored?.updatedAt == fixedNow)
    }

    @Test func mirrorsUnderTheCurrentlySignedInUserNotSomeoneElse() async throws {
        // A profile save while signed in as user-2 must key the synced row
        // to user-2, never user-1 (even if user-1 was signed in earlier) —
        // the DUT-371 per-user keying on the WRITE side.
        let sessionStore = InMemoryAppleAuthSessionStore(
            initial: AppleAuthSession(userIdentifier: "user-2")
        )
        let syncStore = InMemoryProfileSyncStore()
        let coordinator = makeCoordinator(
            sessionStore: sessionStore,
            syncStore: syncStore,
            isICloudSyncEnabled: { true },
            defaults: isolatedDefaults()
        )
        try await coordinator.save(UserProfile(id: UUID(), displayName: "Spencer", email: "spencer@example.com"))

        #expect(try await syncStore.fetch(ownerUserIdentifier: "user-2")?.displayName == "Spencer")
        #expect(try await syncStore.fetch(ownerUserIdentifier: "user-1") == nil)
    }
}

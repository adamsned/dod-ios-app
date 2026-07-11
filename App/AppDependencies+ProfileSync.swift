import DODFeatureProfile
import DODPersistence
import DODSupport
import Foundation

/// DUT-943 Scope A — CloudKit profile sync (display name / email / avatar
/// photo), iOS ↔ iOS only, layered on top of the existing US-44 profile
/// editor and the DUT-35 CloudKit-sync opt-in flag. Lives in the App target
/// (not `DODFeatureProfile`) because bridging `ProfileSyncStoring` to
/// `RecipeStore`'s SwiftData `SyncedProfile` model requires linking
/// `DODPersistence`, which `DODFeatureProfile` deliberately does not depend
/// on (same posture as `LiveSavedDependencies` / `LiveRecipeDetailDependencies`
/// bridging their own package's seams to `RecipeStore` here).
///
/// **HIGH RISK — flagged for review (see the PR description):**
/// 1. This is the SECOND model ever added to CloudKit's `.private` mirror
///    configuration (after DUT-35's `SyncedSavedRecipe`) — exactly the
///    category DUT-35's own postmortem (DOD-CRASH-1) warned about.
/// 2. It ships a schema/data-model version bump (`SchemaV6` -> `SchemaV7`,
///    see `DODPersistence/SchemaV7.swift`).
/// 3. It CANNOT be verified in CI or the Simulator — CloudKit mirroring is
///    gated off on the Simulator (`RecipeStore.cloudKitMirroringAvailable`)
///    and a unit-test process can't construct a `.private` container at all.
///    Real verification requires TWO physical devices signed into the SAME
///    iCloud account, both opted into iCloud Sync, both signed into the SAME
///    Apple/Google profile.
extension AppDependencies {

    /// Bridges `ProfileSyncStoring` (defined in `DODFeatureProfile`, which
    /// has no SwiftData dependency) to `RecipeStore`'s `SyncedProfile` model.
    /// The App target is the only place both packages meet.
    struct LiveProfileSyncStore: ProfileSyncStoring {
        let store: RecipeStore

        func upsert(_ record: SyncedProfileRecord) async throws {
            try await store.upsertSyncedProfile(
                ownerUserIdentifier: record.ownerUserIdentifier,
                displayName: record.displayName,
                email: record.email,
                photoData: record.photoData,
                updatedAt: record.updatedAt
            )
        }

        func fetch(ownerUserIdentifier: String) async throws -> SyncedProfileRecord? {
            guard
                let snapshot = try await store.syncedProfileSnapshot(
                    ownerUserIdentifier: ownerUserIdentifier
                )
            else { return nil }
            return SyncedProfileRecord(
                ownerUserIdentifier: snapshot.ownerUserIdentifier,
                displayName: snapshot.displayName,
                email: snapshot.email,
                photoData: snapshot.photoData,
                updatedAt: snapshot.updatedAt
            )
        }
    }

    /// Build the DUT-943 Scope A profile-sync coordinator, wrapping the
    /// Keychain profile store + Documents photo store with the CloudKit
    /// mirror. Reuses the SAME iCloud-Sync opt-in flag
    /// (`RecipeStore.cloudKitSyncOptIn()`) and the SAME Apple/Google sign-in
    /// session (`KeychainAppleAuthSessionStore`, the provider-neutral session
    /// `AppleProfileSignIn` / `GoogleProfileSignIn` already write) every
    /// other profile / sign-in surface reads — no new toggle, no new
    /// identity seam (per the task's explicit instruction to reuse existing
    /// seams rather than invent new ones).
    static func makeProfileSyncCoordinator(
        profileStore: KeychainProfileStore,
        photoStore: ProfilePhotoStore?,
        recipeStore: RecipeStore
    ) -> ProfileSyncCoordinator {
        ProfileSyncCoordinator(
            wrapping: profileStore,
            photoStore: photoStore,
            sessionStore: KeychainAppleAuthSessionStore(),
            syncStore: LiveProfileSyncStore(store: recipeStore),
            isICloudSyncEnabled: { RecipeStore.cloudKitSyncOptIn() }
        )
    }

    /// DUT-943 Scope A — reconcile once immediately, then on every CloudKit
    /// remote-change signal for the app's lifetime. Reuses
    /// `SavedRemoteChangeBridge` (built for the Saved tab's DUT-6 live
    /// refresh) rather than adding a second `NotificationCenter` observer:
    /// `SyncedProfile` lives in the SAME named `"SyncedSaved"`
    /// store/configuration as `SyncedSavedRecipe` (see
    /// `RecipeStore+Containers.swift`'s `syncedSavedConfiguration`), so the
    /// exact same `NSPersistentStoreRemoteChange` /
    /// `NSPersistentCloudKitContainer.eventChangedNotification` events that
    /// signal a saved-recipe import ALSO fire on a profile-row import.
    ///
    /// Only called from `bootstrap()` behind the SAME `cloudKitSyncOptIn()`
    /// gate as `cloudKitDiagnostics.start()` / `checkCloudKitAvailability()`,
    /// so opted-out users never touch CloudKit here either.
    func startProfileSyncObserving() {
        let coordinator = profileSyncCoordinator
        Task {
            await coordinator.reconcileFromRemote()
            for await _ in SavedRemoteChangeBridge.makeStream() {
                await coordinator.reconcileFromRemote()
            }
        }
    }
}

import DODSupport
import Foundation

#if canImport(UIKit)
import UIKit
#endif

// Cloud -> Local half of DUT-943 Scope A. Extracted from
// `ProfileSyncCoordinator.swift` to keep that file focused on the
// `ProfileStoring` conformance + local -> cloud mirror; mirrors the split
// convention `ProfileEditView` uses (`+Save.swift`, `+Photo.swift`, …).
extension ProfileSyncCoordinator {

    /// Called by the App target at launch and on every CloudKit
    /// remote-change signal (the same `NSPersistentStoreRemoteChange` /
    /// `NSPersistentCloudKitContainer.eventChangedNotification` bridge the
    /// Saved tab's live-refresh already uses — `SyncedProfile` lives in the
    /// SAME `.private` store/configuration as `SyncedSavedRecipe`, so that
    /// notification already fires on a profile-row import; no second
    /// observer is needed).
    ///
    /// No-op when sync is off, no user is signed in, there is no synced row
    /// yet for that user, or the row loses last-writer-wins — see
    /// ``ProfileSyncReconciler``. On a genuine remote win, applies the
    /// display name / email / photo to the LOCAL profile and advances the
    /// local-edit-timestamp baseline to the remote's `updatedAt` (so this
    /// same row is never re-applied, and so a LOCAL edit made after this
    /// point correctly outranks it next time).
    public func reconcileFromRemote() async {
        guard isICloudSyncEnabled() else { return }
        guard
            let currentUserIdentifier = (try? sessionStore.load())?.userIdentifier,
            !currentUserIdentifier.isBlankAppleIdentifier
        else { return }
        guard let record = try? await syncStore.fetch(ownerUserIdentifier: currentUserIdentifier) else {
            return
        }
        let localUpdatedAt = readLocalUpdatedAt()
        guard
            ProfileSyncReconciler.shouldApplyRemote(
                rowOwnerUserIdentifier: record.ownerUserIdentifier,
                currentUserIdentifier: currentUserIdentifier,
                localUpdatedAt: localUpdatedAt,
                remoteUpdatedAt: record.updatedAt
            )
        else { return }
        await applyRemote(record)
    }

    private func applyRemote(_ record: SyncedProfileRecord) async {
        let existing = await wrapped.load()
        let previousPhotoFilename = existing?.photoFilename
        let photoFilename = await persistIncomingPhoto(record.photoData)
        let profile = UserProfile(
            id: existing?.id ?? UUID(),
            displayName: record.displayName,
            email: record.email,
            photoFilename: photoFilename ?? previousPhotoFilename,
            photoOriginalFilename: existing?.photoOriginalFilename
        )
        // Persist through the WRAPPED store directly (not `self.save(_:)`) —
        // applying an incoming row must NOT immediately re-mirror it back to
        // CloudKit with a fresh `.now` timestamp, which would fight every
        // other device's own reconcile in an update loop that never settles.
        guard (try? await wrapped.save(profile)) != nil else { return }
        #if canImport(UIKit)
        if let photoFilename, let previousPhotoFilename, photoFilename != previousPhotoFilename {
            try? await photoStore?.clear(filename: previousPhotoFilename)
        }
        #endif
        writeLocalUpdatedAt(record.updatedAt)
    }

    #if canImport(UIKit)
    private func persistIncomingPhoto(_ data: Data?) async -> String? {
        guard let data, let photoStore, let image = UIImage(data: data) else { return nil }
        return try? await photoStore.save(image)
    }
    #else
    private func persistIncomingPhoto(_ data: Data?) async -> String? { nil }
    #endif
}

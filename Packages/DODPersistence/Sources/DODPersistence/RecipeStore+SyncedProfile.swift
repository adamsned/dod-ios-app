import Foundation
import SwiftData

// MARK: - Synced profile (DUT-943 Scope A)
//
// `SyncedProfile` is the SECOND model mirrored to CloudKit (after
// `SyncedSavedRecipe`, DUT-35) — one row per signed-in user, carrying just
// display name / email / a single small avatar JPEG so setting the profile
// picture on one device shows on the others. `DODFeatureProfile` never talks
// to SwiftData directly (it has no dependency on this package); the App
// target's `LiveProfileSyncStore` adapter is the only caller of these
// methods, translating to/from the `SyncedProfileRecord` DTO that package
// defines. See `SyncedProfile.swift` for the model + CloudKit-clean
// invariants, and `ProfileSyncCoordinator` (DODFeatureProfile) for the
// mirror-on-save / apply-on-reconcile orchestration + per-user-keying /
// last-writer-wins decisions.
extension RecipeStore {

    /// A `Sendable` snapshot of a `SyncedProfile` row, safe to hand back to a
    /// non-isolated caller across the `@ModelActor` boundary (mirrors
    /// `RecipeStore.toDomain(_:)`'s DTO pattern for `SyncedSavedRecipe`).
    public struct SyncedProfileSnapshot: Sendable, Equatable {
        public let ownerUserIdentifier: String
        public let displayName: String
        public let email: String
        public let photoData: Data?
        public let updatedAt: Date

        public init(
            ownerUserIdentifier: String,
            displayName: String,
            email: String,
            photoData: Data?,
            updatedAt: Date
        ) {
            self.ownerUserIdentifier = ownerUserIdentifier
            self.displayName = displayName
            self.email = email
            self.photoData = photoData
            self.updatedAt = updatedAt
        }
    }

    /// All synced profile rows for a given owner. Normally one, but — exactly
    /// like `SyncedSavedRecipe` (DUT-378) — `SyncedProfile` carries no
    /// `@Attribute(.unique)` (CloudKit forbids it), so two devices writing
    /// offline can each insert their own CKRecord for the same user. Every
    /// lookup tolerates duplicates and collapses to the newest by
    /// `updatedAt`.
    func fetchAllSyncedProfiles(ownerUserIdentifier: String) throws -> [SyncedProfile] {
        let descriptor = FetchDescriptor<SyncedProfile>(
            predicate: #Predicate { $0.ownerUserIdentifier == ownerUserIdentifier }
        )
        return try modelContext.fetch(descriptor)
    }

    /// Insert-or-update the synced profile row for `ownerUserIdentifier`.
    /// Collapses any CloudKit-duplicate rows into the NEWEST-`updatedAt` one
    /// first (mirrors `upsertSyncedSaved`'s DUT-650 collapse), then overwrites
    /// it with the given fields. A blank `ownerUserIdentifier` is rejected —
    /// it is never a valid per-user key (mirrors the `isBlankAppleIdentifier`
    /// guard `AppleAuthSession` / `AppleProfileSignIn` use at every other
    /// signed-in-user boundary).
    public func upsertSyncedProfile(
        ownerUserIdentifier: String,
        displayName: String,
        email: String,
        photoData: Data?,
        updatedAt: Date = .now
    ) throws {
        guard !ownerUserIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        let existingRows = try fetchAllSyncedProfiles(ownerUserIdentifier: ownerUserIdentifier)
        if let existing = existingRows.max(by: { $0.updatedAt < $1.updatedAt }) {
            for duplicate in existingRows where duplicate !== existing {
                modelContext.delete(duplicate)
            }
            existing.displayName = displayName
            existing.email = email
            existing.photoData = photoData
            existing.updatedAt = updatedAt
        } else {
            modelContext.insert(
                SyncedProfile(
                    ownerUserIdentifier: ownerUserIdentifier,
                    displayName: displayName,
                    email: email,
                    photoData: photoData,
                    updatedAt: updatedAt
                )
            )
        }
        try modelContext.save()
    }

    /// Read the synced profile row for `ownerUserIdentifier`, if any, as a
    /// `Sendable` snapshot. Returns the newest of any CloudKit-duplicate rows
    /// (same collapse-by-`updatedAt` tie-break as the write side); does NOT
    /// mutate the store (no collapse-write here — that happens lazily on the
    /// next ``upsertSyncedProfile`` for this owner).
    public func syncedProfileSnapshot(ownerUserIdentifier: String) throws -> SyncedProfileSnapshot? {
        guard
            let row = try fetchAllSyncedProfiles(ownerUserIdentifier: ownerUserIdentifier)
                .max(by: { $0.updatedAt < $1.updatedAt })
        else { return nil }
        return SyncedProfileSnapshot(
            ownerUserIdentifier: row.ownerUserIdentifier,
            displayName: row.displayName,
            email: row.email,
            photoData: row.photoData,
            updatedAt: row.updatedAt
        )
    }
}

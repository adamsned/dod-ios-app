import DODSupport
import Foundation

#if canImport(UIKit)
import UIKit
#endif

/// DUT-943 Scope A — mirrors the local ``UserProfile`` (+ avatar photo) to
/// the signed-in user's CloudKit private database via `SyncedProfile`
/// (in `DODPersistence`, reached only through the ``ProfileSyncStoring``
/// seam so this package stays free of a SwiftData dependency), and applies an
/// incoming synced row back to the local profile + avatar file. iOS ↔ iOS
/// only; per-user keyed so one person's profile never bleeds onto another's
/// device on a shared iCloud account (DUT-371).
///
/// **A transparent decorator, not a new seam.** `ProfileSyncCoordinator`
/// itself conforms to ``ProfileStoring`` and wraps an existing conformance
/// (production: `KeychainProfileStore`). The composition root
/// (`AppDependencies`) constructs it ONCE and hands it out wherever
/// `any ProfileStoring` is already threaded — `ProfileEditView`,
/// `AppleProfileSignIn`, `GoogleProfileSignIn`, `SettingsViewModel` — so
/// EVERY existing profile-save call site gets the mirror-on-save behavior
/// for free, with zero changes to those call sites. When wrapped around a
/// bare `KeychainProfileStore` (no coordinator), or when this coordinator's
/// gates simply decline (sync off / signed out), behavior is byte-identical
/// to today.
///
/// **The two directions live in two files.** This file: `ProfileStoring`
/// passthrough + the local -> cloud mirror-on-save. `+ApplyRemote.swift`:
/// the cloud -> local reconcile, called by the App target at launch and on
/// every CloudKit remote-change signal.
///
/// **Gating (reuses existing seams — see `ProfileSyncReconciler`).** Mirrors
/// only fire when `isICloudSyncEnabled()` is true (the App target wires this
/// to `RecipeStore.cloudKitSyncOptIn()` — the SAME flag every other CloudKit
/// decision in this app reads) AND `sessionStore.load()?.userIdentifier` is a
/// real, non-blank id (the SAME `AppleAuthSession` the Apple/Google sign-in
/// flows already persist — no new identity seam). With sync off or no user
/// signed in, `save(_:)` behaves exactly like the wrapped store: profile
/// stays fully local, exactly as today.
public actor ProfileSyncCoordinator: ProfileStoring {

    /// `UserDefaults` key for this device's last-local-profile-edit
    /// timestamp. `UserProfile` carries no `updatedAt` field of its own (it
    /// predates DUT-943 and changing its `Codable` shape is out of scope), so
    /// this is tracked alongside it — written on every successful
    /// ``save(_:)`` (whether or not sync is on, so the timestamp is honest
    /// the moment a user opts in) and read by ``reconcileFromRemote()`` as
    /// the local side of last-writer-wins. `public` so tests can seed/inspect
    /// it against an isolated `UserDefaults` suite.
    public static let localUpdatedAtKey = "dod.cloudkit.profileLocalUpdatedAtV1"

    let wrapped: any ProfileStoring
    #if canImport(UIKit)
    let photoStore: (any ProfilePhotoStoring)?
    #endif
    let sessionStore: any AppleAuthSessionStoring
    let syncStore: any ProfileSyncStoring
    let isICloudSyncEnabled: @Sendable () -> Bool
    let readLocalUpdatedAt: @Sendable () -> Date
    let writeLocalUpdatedAt: @Sendable (Date) -> Void
    let now: @Sendable () -> Date

    /// `UserDefaults` does not conform to `Sendable` in this SDK, so it can't
    /// be captured directly into the `@Sendable` closures below. `UserDefaults`
    /// IS thread-safe in practice (every other `UserDefaults` access in this
    /// codebase — `RecipeStore.cloudKitSyncOptIn(in:)` etc. — relies on the
    /// same fact, just without ever capturing it into a stored closure); this
    /// box exists purely to tell the compiler what's already true.
    private final class UncheckedDefaultsBox: @unchecked Sendable {
        let defaults: UserDefaults
        init(_ defaults: UserDefaults) { self.defaults = defaults }
    }

    /// Default ``readLocalUpdatedAt`` / ``writeLocalUpdatedAt`` pair backed by
    /// `UserDefaults.standard` (or an injected suite) under
    /// ``localUpdatedAtKey``. Tests inject their own pair against an isolated
    /// `UserDefaults` suite the same way `RecipeStore.cloudKitSyncOptIn(in:)`
    /// callers do.
    public static func standardDefaultsAccessors(
        defaults: UserDefaults = .standard
    ) -> (read: @Sendable () -> Date, write: @Sendable (Date) -> Void) {
        let box = UncheckedDefaultsBox(defaults)
        return (
            read: { Date(timeIntervalSince1970: box.defaults.double(forKey: localUpdatedAtKey)) },
            write: { box.defaults.set($0.timeIntervalSince1970, forKey: localUpdatedAtKey) }
        )
    }

    #if canImport(UIKit)
    public init(
        wrapping store: any ProfileStoring,
        photoStore: (any ProfilePhotoStoring)?,
        sessionStore: any AppleAuthSessionStoring,
        syncStore: any ProfileSyncStoring,
        isICloudSyncEnabled: @escaping @Sendable () -> Bool,
        readLocalUpdatedAt: @escaping @Sendable () -> Date = standardDefaultsAccessors().read,
        writeLocalUpdatedAt: @escaping @Sendable (Date) -> Void = standardDefaultsAccessors().write,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.wrapped = store
        self.photoStore = photoStore
        self.sessionStore = sessionStore
        self.syncStore = syncStore
        self.isICloudSyncEnabled = isICloudSyncEnabled
        self.readLocalUpdatedAt = readLocalUpdatedAt
        self.writeLocalUpdatedAt = writeLocalUpdatedAt
        self.now = now
    }
    #else
    public init(
        wrapping store: any ProfileStoring,
        sessionStore: any AppleAuthSessionStoring,
        syncStore: any ProfileSyncStoring,
        isICloudSyncEnabled: @escaping @Sendable () -> Bool,
        readLocalUpdatedAt: @escaping @Sendable () -> Date = standardDefaultsAccessors().read,
        writeLocalUpdatedAt: @escaping @Sendable (Date) -> Void = standardDefaultsAccessors().write,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.wrapped = store
        self.sessionStore = sessionStore
        self.syncStore = syncStore
        self.isICloudSyncEnabled = isICloudSyncEnabled
        self.readLocalUpdatedAt = readLocalUpdatedAt
        self.writeLocalUpdatedAt = writeLocalUpdatedAt
        self.now = now
    }
    #endif

    // MARK: - ProfileStoring

    public func load() async -> UserProfile? {
        await wrapped.load()
    }

    /// Persists via the wrapped store (unchanged validation/error contract),
    /// records this device's local-edit timestamp, then mirrors to CloudKit
    /// when ``ProfileSyncReconciler/shouldMirrorLocalSave(isICloudSyncEnabled:currentUserIdentifier:)``
    /// says to. The mirror is best-effort (`try?`) — a CloudKit write failure
    /// must never fail the LOCAL save the user is waiting on.
    public func save(_ profile: UserProfile) async throws {
        try await wrapped.save(profile)
        writeLocalUpdatedAt(now())
        await mirrorToCloudIfNeeded(profile)
    }

    /// DUT-943 Scope A ships no CloudKit-delete propagation: signing out or
    /// deleting the profile on this device does not remove (or blank) the
    /// `SyncedProfile` row, so another signed-in device keeps whatever it
    /// last saw. This mirrors the pre-existing local Sign Out / Delete
    /// Profile semantics (both already just clear the LOCAL Keychain row —
    /// see `KeychainProfileStore.clear()`'s doc comment) and is called out
    /// explicitly in the PR as a known Scope A limitation.
    public func clear() async throws {
        try await wrapped.clear()
    }

    public var hasProfile: Bool {
        get async { await wrapped.hasProfile }
    }

    // MARK: - Local -> Cloud

    private func mirrorToCloudIfNeeded(_ profile: UserProfile) async {
        let currentUserIdentifier: String? = (try? sessionStore.load())?.userIdentifier
        guard
            ProfileSyncReconciler.shouldMirrorLocalSave(
                isICloudSyncEnabled: isICloudSyncEnabled(),
                currentUserIdentifier: currentUserIdentifier
            ),
            let ownerUserIdentifier = currentUserIdentifier
        else { return }
        let photoData = await loadPhotoData(filename: profile.photoFilename)
        let record = SyncedProfileRecord(
            ownerUserIdentifier: ownerUserIdentifier,
            displayName: profile.displayName,
            email: profile.email,
            photoData: photoData,
            updatedAt: now()
        )
        try? await syncStore.upsert(record)
    }

    #if canImport(UIKit)
    private func loadPhotoData(filename: String?) async -> Data? {
        guard let filename, let photoStore else { return nil }
        guard let image = await photoStore.load(filename: filename) else { return nil }
        return image.jpegData(compressionQuality: ProfilePhotoStore.jpegQuality)
    }
    #else
    private func loadPhotoData(filename: String?) async -> Data? { nil }
    #endif
}

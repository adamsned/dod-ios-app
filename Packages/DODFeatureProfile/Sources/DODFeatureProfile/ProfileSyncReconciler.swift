import DODSupport
import Foundation

/// DUT-943 Scope A — pure reconciliation decisions for CloudKit profile sync.
/// No I/O, no Keychain, no CloudKit, no SwiftData — every function is a
/// static, deterministic transform over plain values, so the L1 suite can pin
/// the cross-device merge logic (per-user keying + last-writer-wins) without
/// touching any store. `ProfileSyncCoordinator` is the only caller; it owns
/// all the actual reads/writes and calls these functions to decide WHAT to
/// do.
public enum ProfileSyncReconciler {

    /// DUT-371 cross-user-bleed guard: a synced row only ever applies to the
    /// CURRENTLY signed-in user on THIS device. `nil` / blank
    /// `currentUserIdentifier` (signed out, or a blank/corrupt session) never
    /// matches ANY row — a signed-out device must never adopt anyone's
    /// synced profile. A shared iCloud account (e.g. Family Sharing) can
    /// carry `SyncedProfile` rows for multiple Apple/Google user ids in the
    /// same private database; this is the guard that keeps them from
    /// bleeding onto each other's devices.
    public static func isForCurrentUser(
        rowOwnerUserIdentifier: String,
        currentUserIdentifier: String?
    ) -> Bool {
        guard let currentUserIdentifier, !currentUserIdentifier.isBlankAppleIdentifier else {
            return false
        }
        return rowOwnerUserIdentifier == currentUserIdentifier
    }

    /// Last-writer-wins outcome between the local device's own profile and an
    /// incoming synced row.
    public enum Winner: Sendable, Equatable {
        case local
        case remote
    }

    /// `remote` wins only on a STRICTLY newer `updatedAt`. A tie (including
    /// the common "this device never recorded a local edit timestamp"
    /// `.distantPast` baseline, which loses to any real remote timestamp)
    /// favors `local` — so applying a remote row is never mistaken for a
    /// no-op local re-save fighting itself.
    public static func winner(localUpdatedAt: Date, remoteUpdatedAt: Date) -> Winner {
        remoteUpdatedAt > localUpdatedAt ? .remote : .local
    }

    /// The combined decision `ProfileSyncCoordinator.reconcileFromRemote()`
    /// actually needs: apply the incoming row to the local profile only when
    /// it is BOTH for the current user AND wins last-writer-wins.
    public static func shouldApplyRemote(
        rowOwnerUserIdentifier: String,
        currentUserIdentifier: String?,
        localUpdatedAt: Date,
        remoteUpdatedAt: Date
    ) -> Bool {
        guard
            isForCurrentUser(
                rowOwnerUserIdentifier: rowOwnerUserIdentifier,
                currentUserIdentifier: currentUserIdentifier
            )
        else { return false }
        return winner(localUpdatedAt: localUpdatedAt, remoteUpdatedAt: remoteUpdatedAt) == .remote
    }

    /// The gate for the OTHER direction: should a local profile save be
    /// mirrored to CloudKit at all? Both conditions are required — sync must
    /// be on, AND a real (non-blank) user must be signed in — matching the
    /// task's "iCloud Sync toggle + signed-in user" gate, reusing the same
    /// blank-identifier check every other signed-in-user boundary in this
    /// codebase uses (`AppleAuthSession.isBlankAppleIdentifier`).
    public static func shouldMirrorLocalSave(
        isICloudSyncEnabled: Bool,
        currentUserIdentifier: String?
    ) -> Bool {
        guard isICloudSyncEnabled, let currentUserIdentifier, !currentUserIdentifier.isBlankAppleIdentifier
        else { return false }
        return true
    }
}

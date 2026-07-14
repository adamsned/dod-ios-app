import Foundation
import Testing

@testable import DODFeatureProfile

/// DUT-943 Scope A — pure reconciliation-decision coverage. No stores, no
/// CloudKit, no Keychain: every case pins a deterministic input/output pair
/// for ``ProfileSyncReconciler``'s per-user-keying (DUT-371) and
/// last-writer-wins rules.
@Suite("ProfileSyncReconciler (DUT-943 Scope A)")
struct ProfileSyncReconcilerTests {

    // MARK: - isForCurrentUser (DUT-371 cross-user-bleed guard)

    @Test func matchingOwnerIsForCurrentUser() {
        #expect(
            ProfileSyncReconciler.isForCurrentUser(
                rowOwnerUserIdentifier: "user-1",
                currentUserIdentifier: "user-1"
            )
        )
    }

    @Test func differentOwnerIsNotForCurrentUser() {
        #expect(
            !ProfileSyncReconciler.isForCurrentUser(
                rowOwnerUserIdentifier: "user-1",
                currentUserIdentifier: "user-2"
            )
        )
    }

    @Test func nilCurrentUserNeverMatchesAnyRow() {
        #expect(
            !ProfileSyncReconciler.isForCurrentUser(
                rowOwnerUserIdentifier: "user-1",
                currentUserIdentifier: nil
            )
        )
    }

    @Test func blankCurrentUserNeverMatchesAnyRow() {
        // A blank/whitespace-only identifier must never be treated as a real
        // signed-in user — mirrors `AppleAuthSession.isBlankAppleIdentifier`
        // at every other signed-in-user boundary (DUT-506).
        #expect(
            !ProfileSyncReconciler.isForCurrentUser(
                rowOwnerUserIdentifier: "user-1",
                currentUserIdentifier: "   "
            )
        )
    }

    @Test func blankOwnerAndBlankCurrentStillDoNotMatch() {
        // Two blanks comparing equal would be the DUT-506 phantom-session
        // bug reborn — the guard must reject on the CURRENT side regardless
        // of what the row's owner id happens to be.
        #expect(
            !ProfileSyncReconciler.isForCurrentUser(
                rowOwnerUserIdentifier: "",
                currentUserIdentifier: ""
            )
        )
    }

    // MARK: - winner (last-writer-wins)

    @Test func strictlyNewerRemoteWins() {
        let winner = ProfileSyncReconciler.winner(
            localUpdatedAt: Date(timeIntervalSince1970: 100),
            remoteUpdatedAt: Date(timeIntervalSince1970: 200)
        )
        #expect(winner == .remote)
    }

    @Test func strictlyNewerLocalWins() {
        let winner = ProfileSyncReconciler.winner(
            localUpdatedAt: Date(timeIntervalSince1970: 200),
            remoteUpdatedAt: Date(timeIntervalSince1970: 100)
        )
        #expect(winner == .local)
    }

    @Test func exactTieFavorsLocal() {
        let timestamp = Date(timeIntervalSince1970: 100)
        let winner = ProfileSyncReconciler.winner(
            localUpdatedAt: timestamp,
            remoteUpdatedAt: timestamp
        )
        #expect(winner == .local, "A tie must not clobber the local edit that produced it")
    }

    @Test func neverTrackedLocalTimestampLosesToAnyRealRemoteTimestamp() {
        // `.distantPast` is the baseline for a device that has never recorded
        // a local edit (fresh install, or pre-DUT-943 profile) — a real
        // remote row should win so a new device joining sync adopts the
        // existing cross-device profile.
        let winner = ProfileSyncReconciler.winner(
            localUpdatedAt: .distantPast,
            remoteUpdatedAt: Date(timeIntervalSince1970: 1)
        )
        #expect(winner == .remote)
    }

    // MARK: - shouldApplyRemote (combined gate)

    @Test func appliesRemoteOnlyWhenForCurrentUserAndRemoteWins() {
        #expect(
            ProfileSyncReconciler.shouldApplyRemote(
                rowOwnerUserIdentifier: "user-1",
                currentUserIdentifier: "user-1",
                localUpdatedAt: Date(timeIntervalSince1970: 100),
                remoteUpdatedAt: Date(timeIntervalSince1970: 200)
            )
        )
    }

    @Test func neverAppliesRemoteForADifferentUserEvenIfItWouldWin() {
        // The DUT-371 guard is checked FIRST — a newer remote row for someone
        // else's account must never apply, no matter the timestamps.
        #expect(
            !ProfileSyncReconciler.shouldApplyRemote(
                rowOwnerUserIdentifier: "user-2",
                currentUserIdentifier: "user-1",
                localUpdatedAt: .distantPast,
                remoteUpdatedAt: Date(timeIntervalSince1970: 200)
            )
        )
    }

    @Test func neverAppliesRemoteWhenLocalIsNewerEvenForTheSameUser() {
        #expect(
            !ProfileSyncReconciler.shouldApplyRemote(
                rowOwnerUserIdentifier: "user-1",
                currentUserIdentifier: "user-1",
                localUpdatedAt: Date(timeIntervalSince1970: 500),
                remoteUpdatedAt: Date(timeIntervalSince1970: 200)
            )
        )
    }

    @Test func neverAppliesRemoteWhenSignedOut() {
        #expect(
            !ProfileSyncReconciler.shouldApplyRemote(
                rowOwnerUserIdentifier: "user-1",
                currentUserIdentifier: nil,
                localUpdatedAt: .distantPast,
                remoteUpdatedAt: Date(timeIntervalSince1970: 200)
            )
        )
    }

    // MARK: - shouldMirrorLocalSave (local -> cloud gate)

    @Test func mirrorsWhenSyncOnAndSignedIn() {
        #expect(
            ProfileSyncReconciler.shouldMirrorLocalSave(
                isICloudSyncEnabled: true,
                currentUserIdentifier: "user-1"
            )
        )
    }

    @Test func doesNotMirrorWhenSyncOff() {
        #expect(
            !ProfileSyncReconciler.shouldMirrorLocalSave(
                isICloudSyncEnabled: false,
                currentUserIdentifier: "user-1"
            )
        )
    }

    @Test func doesNotMirrorWhenNoUserSignedIn() {
        #expect(
            !ProfileSyncReconciler.shouldMirrorLocalSave(
                isICloudSyncEnabled: true,
                currentUserIdentifier: nil
            )
        )
    }

    @Test func doesNotMirrorWhenSignedInIdentifierIsBlank() {
        #expect(
            !ProfileSyncReconciler.shouldMirrorLocalSave(
                isICloudSyncEnabled: true,
                currentUserIdentifier: "   "
            )
        )
    }

    @Test func doesNotMirrorWhenBothConditionsFail() {
        #expect(
            !ProfileSyncReconciler.shouldMirrorLocalSave(
                isICloudSyncEnabled: false,
                currentUserIdentifier: nil
            )
        )
    }
}

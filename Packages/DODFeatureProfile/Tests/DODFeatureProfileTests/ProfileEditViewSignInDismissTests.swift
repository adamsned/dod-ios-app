import Foundation
import Testing

@testable import DODFeatureProfile

/// (this bug) regression L1 for ``ProfileEditView/shouldDismissAfterSignIn(outcome:)`` —
/// the shared policy behind DUT-935's "never trap a signed-in user on the
/// profile editor sheet" rule. Before this fix `handleGoogleSignIn` still
/// gated dismissal on `outcome.profileSaved`, which DUT-935 had already
/// removed from `handleAppleSignIn`: a successful Google sign-in whose
/// credential carried no profile data (a restored session, or an account
/// with no public profile name) left the user stuck on the sheet looking
/// like sign-in had failed, even though they were genuinely signed in.
///
/// These pin the policy directly on the pure helper both handlers now share,
/// so it can never again drift apart between the Apple and Google paths.
@Suite("ProfileEditView sign-in dismiss policy ((this bug))")
struct ProfileEditViewSignInDismissTests {

    /// The KEY regression case: signed in, but the credential carried no
    /// profile to auto-fill (`profileSaved == false`) and that absence is NOT
    /// a write failure. Must still dismiss — this is the exact shape
    /// `GoogleProfileSignIn.apply` returns for a Google credential missing a
    /// display name/email (e.g. a restored session), and what
    /// `AppleProfileSignIn.apply` returns for an Apple re-auth.
    @Test func dismissesWhenSignedInWithNothingToAutoFill() {
        let outcome = AppleProfileSignIn.Outcome(
            displayName: nil,
            email: nil,
            profileSaved: false,
            signedIn: true,
            profileWriteFailed: false
        )
        #expect(ProfileEditView.shouldDismissAfterSignIn(outcome: outcome))
    }

    /// Signed in AND a full profile was written in one tap — the common case.
    @Test func dismissesWhenSignedInWithProfileSaved() {
        let outcome = AppleProfileSignIn.Outcome(
            displayName: "Ned Adams",
            email: "ned@example.com",
            profileSaved: true,
            signedIn: true,
            profileWriteFailed: false
        )
        #expect(ProfileEditView.shouldDismissAfterSignIn(outcome: outcome))
    }

    /// A genuine profile-write failure (the credential carried both fields but
    /// the Keychain/profile save threw) must keep the editor open so the host
    /// can surface "Couldn't Save Your Profile" — dismissing would hide the error.
    @Test func doesNotDismissOnGenuineProfileWriteFailure() {
        let outcome = AppleProfileSignIn.Outcome(
            displayName: "Ned Adams",
            email: "ned@example.com",
            profileSaved: false,
            signedIn: true,
            profileWriteFailed: true
        )
        #expect(!ProfileEditView.shouldDismissAfterSignIn(outcome: outcome))
    }

    /// Not signed in at all (e.g. the DUT-506 blank-identifier non-event, or a
    /// DUT-928 session-save failure) must never dismiss — there is nothing to
    /// reflect and the host may need to surface an error.
    @Test func doesNotDismissWhenNotSignedIn() {
        let outcome = AppleProfileSignIn.Outcome(
            displayName: nil,
            email: nil,
            profileSaved: false,
            signedIn: false,
            profileWriteFailed: false
        )
        #expect(!ProfileEditView.shouldDismissAfterSignIn(outcome: outcome))
    }
}

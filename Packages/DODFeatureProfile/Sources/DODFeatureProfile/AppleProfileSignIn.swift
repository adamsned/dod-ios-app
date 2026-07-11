import DODSupport
import Foundation
import Security

/// Full "Sign in with Apple" for the **profile-login surfaces** (DUT-189 / US-46
/// amendment). One tap does two things:
///   1. **Signs the user in** — persists the ``AppleAuthSession`` and (in the
///      background) exchanges the one-time authorization code for a refresh
///      token so in-app account deletion can revoke it (App Store 5.1.1(v)).
///      This is the app's single sign-in path: DUT-238 removed the separate
///      Settings ▸ Account section (and its `AccountViewModel`) and fused
///      sign-in into the profile editor, so this is where the session is created.
///   2. **Fills the local ``UserProfile``** — writes the display name + email
///      from the credential (which the old Settings sign-in never did), so the
///      profile is set up in one tap.
///
/// Pure value type with injected stores (no UIKit) so the L1 suite drives it
/// with in-memory fakes. The UIKit `SignInWithAppleButton` wrapper that feeds
/// it a credential lives in ``AppleProfileSignInButton``.
public struct AppleProfileSignIn: Sendable {

    private let sessionStore: any AppleAuthSessionStoring
    private let profileStore: any ProfileStoring
    private let revoker: (any SiwaRevoking)?

    /// The defaults are the production wiring: the Keychain-backed session store,
    /// and the production revoke client only when the DUT-98 Worker is configured
    /// (else `nil`, so sign-in still works with no exchange/revoke). Tests inject
    /// in-memory fakes.
    public init(
        profileStore: any ProfileStoring,
        sessionStore: any AppleAuthSessionStoring = KeychainAppleAuthSessionStore(),
        revoker: (any SiwaRevoking)? = SiwaRevokeConfig.production.isConfigured
            ? SiwaRevokeClient(config: SiwaRevokeConfig.production) : nil
    ) {
        self.profileStore = profileStore
        self.sessionStore = sessionStore
        self.revoker = revoker
    }

    /// What the caller should reflect in the UI after a sign-in.
    public struct Outcome: Sendable, Equatable {
        /// The display name resolved from the credential (carried forward for a
        /// returning user), or `nil` if Apple withheld it and none was on file.
        public let displayName: String?
        /// The email, same resolution rules as `displayName`.
        public let email: String?
        /// `true` when a **valid** ``UserProfile`` was persisted (both fields
        /// passed validation) — the host can dismiss for a true one-tap setup.
        /// `false` means Apple withheld the fields and nothing was on file to
        /// fill, so the host should keep the editor open for manual completion
        /// (the session is still persisted — the user IS signed in).
        public let profileSaved: Bool
        /// `true` when a session was actually persisted — i.e. the sign-in itself
        /// succeeded. `false` only for the DUT-506 blank-id early return (a
        /// non-event the host stays silent about). This lets the host tell a
        /// *successful* re-auth where Apple withheld the name/email (keep the
        /// editor open for manual entry, NO error) apart from a real failure.
        public let signedIn: Bool
        /// DUT-891b — `true` only when the credential DID carry a name + email but
        /// the profile / Keychain WRITE failed (the genuine "Couldn't Save Your
        /// Profile" case — e.g. a missing keychain entitlement). This is distinct
        /// from the common re-auth path where Apple withholds the fields and there
        /// is simply nothing to write, which is NOT an error. The host surfaces an
        /// error only when this is `true`, never merely because `profileSaved` is
        /// `false`.
        public let profileWriteFailed: Bool

        /// DUT-928 — `true` when the Keychain WRITE of the session itself failed
        /// (a signed-device Keychain error). Distinct from ``profileWriteFailed``
        /// (the profile row, not the session): a session-save failure means the
        /// user is NOT actually signed in, so ``signedIn`` is `false` and the host
        /// must surface an error rather than silently pretending success — the
        /// "signs in but doesn't stick" bug, where `try?` swallowed the write
        /// error and the outcome still claimed `signedIn: true`.
        public let sessionSaveFailed: Bool
        /// DUT-928 — the raw `OSStatus` from the failed session Keychain write,
        /// carried for on-device diagnosis (`nil` when the save succeeded).
        public let sessionSaveStatus: OSStatus?

        public init(
            displayName: String?,
            email: String?,
            profileSaved: Bool,
            signedIn: Bool = true,
            profileWriteFailed: Bool = false,
            sessionSaveFailed: Bool = false,
            sessionSaveStatus: OSStatus? = nil
        ) {
            self.displayName = displayName
            self.email = email
            self.profileSaved = profileSaved
            self.signedIn = signedIn
            self.profileWriteFailed = profileWriteFailed
            self.sessionSaveFailed = sessionSaveFailed
            self.sessionSaveStatus = sessionSaveStatus
        }
    }

    /// Persist the session, write the profile when the credential carries both
    /// fields, and kick off the background refresh-token exchange. Returns what
    /// to reflect in the UI.
    @discardableResult
    public func apply(
        userIdentifier: String,
        displayName: String?,
        email: String?,
        authorizationCode: String?
    ) async -> Outcome {
        // DUT-506: an empty / whitespace-only identifier is NOT a valid sign-in —
        // it would persist a phantom `""`-keyed session (making `hasSession` true)
        // and make `AppleCredentialResolver.resolve` treat every empty-id user as
        // the "same" user (`"" == ""`), bleeding name/email/refreshToken across
        // people. Bail BEFORE resolve/revoke/save so none of that runs (and so the
        // DUT-503 revoke never fires on a `""` id). Mirrors the GIDSignInProvider
        // guard on the Google side (DUT-285), which drops an empty id to `.failed`.
        guard !userIdentifier.isBlankAppleIdentifier else {
            return Outcome(
                displayName: nil,
                email: nil,
                profileSaved: false,
                signedIn: false
            )
        }

        // 1. Session — resolve (carrying first-auth name/email forward for the
        //    same user) + persist immediately, exactly like applySignIn.
        let existingSession = try? sessionStore.load()
        let resolved = AppleCredentialResolver.resolve(
            userIdentifier: userIdentifier,
            credentialDisplayName: displayName,
            credentialEmail: email,
            existing: existingSession
        )
        let sameUser = existingSession?.userIdentifier == userIdentifier
        // DUT-503: if a DIFFERENT user's session (with a refresh token) is on file,
        // revoke it BEFORE we overwrite it — otherwise that token is orphaned
        // (dropped from the Keychain, never revoked), re-opening the 5.1.1(v) gap.
        // Same-user re-auth carries the token forward instead. Mirrors the Google
        // path (DUT-279) so the two sign-in surfaces behave identically.
        let orphanedToken = sameUser ? nil : existingSession?.refreshToken
        if let orphanedToken, let revoker {
            try? await revoker.revoke(refreshToken: orphanedToken)
        }
        // DUT-375: `resolve` now carries the refresh token forward itself (same
        // user) / nils it (different user), so we persist `resolved` directly
        // rather than re-merging the token here.
        // DUT-928: a Keychain WRITE failure here means the user is NOT actually
        // signed in — do NOT fall through returning `signedIn: true` (the silent
        // "signs in but doesn't stick" bug). `persistSession` returns a failure
        // Outcome (carrying the raw OSStatus) the host surfaces as a real error.
        if let failure = persistSession(resolved) { return failure }

        // 2. Profile — the new half. Only write when BOTH fields are known
        //    (a `UserProfile` save validates non-empty name + a real email).
        let profileSaved = await writeProfile(
            resolved: resolved,
            existingSession: existingSession,
            sameUser: sameUser
        )
        // DUT-891b — a write failure is ONLY the "both fields present but the save
        // failed" case. `profileSaved == false` with no fields to write (the common
        // re-auth path) is not a failure — the user is still signed in.
        let credentialCarriedBothFields = resolved.displayName != nil && resolved.email != nil
        let profileWriteFailed = credentialCarriedBothFields && !profileSaved

        // 3. Refresh-token exchange — fire-and-forget so sign-in feels instant
        //    (the token only matters later, for deletion revocation). See
        //    `scheduleRefreshTokenExchange`.
        if let authorizationCode, let revoker {
            scheduleRefreshTokenExchange(
                authorizationCode: authorizationCode,
                revoker: revoker,
                userIdentifier: resolved.userIdentifier,
                displayName: resolved.displayName,
                email: resolved.email
            )
        }

        return Outcome(
            displayName: resolved.displayName,
            email: resolved.email,
            profileSaved: profileSaved,
            signedIn: true,
            profileWriteFailed: profileWriteFailed
        )
    }

    /// DUT-928 — persist the resolved session. Returns `nil` on success, or the
    /// "not signed in" failure ``Outcome`` (carrying the raw `OSStatus`) when the
    /// Keychain WRITE throws — so the caller returns it directly instead of the
    /// former silent `try?`-swallowed success that left the user believing they
    /// were signed in while nothing persisted.
    private func persistSession(_ resolved: AppleAuthSession) -> Outcome? {
        do {
            try sessionStore.save(resolved)
            return nil
        } catch {
            return Outcome(
                displayName: resolved.displayName,
                email: resolved.email,
                profileSaved: false,
                signedIn: false,
                sessionSaveFailed: true,
                sessionSaveStatus: Self.keychainStatus(from: error)
            )
        }
    }

    /// DUT-928 — the raw `OSStatus` behind a session-save error, when it was a
    /// Keychain failure (`nil` otherwise), for the on-device diagnostic.
    private static func keychainStatus(from error: any Error) -> OSStatus? {
        guard let authError = error as? AppleAuthError,
            case .keychainFailed(let code) = authError
        else { return nil }
        return code
    }

    /// Write the local ``UserProfile`` from the resolved credential, returning
    /// whether a valid profile was persisted. Only writes when BOTH name + email
    /// are known; merges into the existing profile to preserve its id + photo.
    private func writeProfile(
        resolved: AppleAuthSession,
        existingSession: AppleAuthSession?,
        sameUser: Bool
    ) async -> Bool {
        guard let name = resolved.displayName, let mail = resolved.email else { return false }
        // DUT-371: don't inherit a DIFFERENT signed-in user's profile id/photo on a
        // shared device. A residual profile is mergeable only when it's the same
        // Apple user, or when there's no prior session at all (a guest / manually-
        // created profile this first sign-in is legitimately claiming — so we don't
        // discard their photo). A different user's session present means the on-file
        // profile is theirs: start fresh.
        let differentUserSignedIn = existingSession != nil && !sameUser
        let existingProfile = differentUserSignedIn ? nil : await profileStore.load()
        let profile = UserProfile(
            id: existingProfile?.id ?? UUID(),
            displayName: name,
            email: mail,
            photoFilename: existingProfile?.photoFilename,
            photoOriginalFilename: existingProfile?.photoOriginalFilename
        )
        return (try? await profileStore.save(profile)) != nil
    }

    /// DUT-266: the async auth-code → refresh-token exchange, fire-and-forget.
    /// Re-saves the session with the token merged in — but ONLY if the session
    /// is STILL the one being signed in. If the user signed out / deleted /
    /// signed in as someone else while the exchange was in flight, the late
    /// write-back is dropped, so it never resurrects a torn-down session or
    /// persists an orphaned (never-revoked) token (the DUT-217 5.1.1(v) gap).
    private func scheduleRefreshTokenExchange(
        authorizationCode: String,
        revoker: any SiwaRevoking,
        userIdentifier: String,
        displayName: String?,
        email: String?
    ) {
        Task {
            guard let token = try? await revoker.exchange(authorizationCode: authorizationCode)
            else { return }
            guard (try? sessionStore.load())?.userIdentifier == userIdentifier else {
                // DUT-368: the session was torn down (sign-out / delete / a different
                // user) while the exchange was in flight. This token, just minted at
                // Apple, will never be stored here — so Delete could never revoke it.
                // Revoke it now directly so it can't outlive the account (App Store
                // 5.1.1(v)); best-effort, it also expires server-side.
                try? await revoker.revoke(refreshToken: token)
                return
            }
            try? sessionStore.save(
                AppleAuthSession(
                    userIdentifier: userIdentifier,
                    displayName: displayName,
                    email: email,
                    refreshToken: token
                )
            )
        }
    }
}

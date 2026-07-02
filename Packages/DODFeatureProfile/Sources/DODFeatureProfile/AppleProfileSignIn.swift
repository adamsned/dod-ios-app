import DODSupport
import Foundation

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
        // DUT-375: `resolve` now carries the refresh token forward itself (same
        // user) / nils it (different user), so we persist `resolved` directly
        // rather than re-merging the token here.
        try? sessionStore.save(resolved)

        // 2. Profile — the new half. Only write when BOTH fields are known
        //    (a `UserProfile` save validates non-empty name + a real email);
        //    merge into the existing profile to preserve its id + photo.
        var profileSaved = false
        if let name = resolved.displayName, let mail = resolved.email {
            // DUT-371: don't inherit a DIFFERENT signed-in user's profile id/photo
            // on a shared device. A residual profile is mergeable only when it's
            // the same Apple user, or when there's no prior session at all (a guest
            // / manually-created profile this first sign-in is legitimately claiming
            // — so we don't discard their photo). A different user's session present
            // means the on-file profile is theirs: start fresh.
            let differentUserSignedIn = existingSession != nil && !sameUser
            let existingProfile = differentUserSignedIn ? nil : await profileStore.load()
            let profile = UserProfile(
                id: existingProfile?.id ?? UUID(),
                displayName: name,
                email: mail,
                photoFilename: existingProfile?.photoFilename,
                photoOriginalFilename: existingProfile?.photoOriginalFilename
            )
            profileSaved = (try? await profileStore.save(profile)) != nil
        }

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
            profileSaved: profileSaved
        )
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

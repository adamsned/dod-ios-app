import DODFeatureProfile
import DODSupport
import Foundation
import Observation

/// State + actions for the Settings → Account section (US-46, AC-46.2..46.6).
/// Owns the on-device ``AppleAuthSession`` via an injected
/// ``AppleAuthSessionStoring`` and turns a Sign in with Apple credential into a
/// persisted session through the pure ``AppleCredentialResolver``.
///
/// Guest mode (US-15) stays the default: a `nil` ``session`` means signed-out.
/// When a ``SiwaRevoking`` revoker is configured (the DUT-98 Worker), sign-in
/// also exchanges the authorization code for a **refresh token** (stored so
/// account deletion can revoke it — App Store 5.1.1(v)). Both the store and the
/// revoker are injected so the L1 suite drives fakes.
@Observable
@MainActor
public final class AccountViewModel {

    /// The current signed-in session, or `nil` when signed out (guest mode).
    public private(set) var session: AppleAuthSession?

    private let store: any AppleAuthSessionStoring
    /// DUT-217: the ``UserProfile`` row written alongside the session at sign-in.
    /// Sign Out / Delete Account must clear it too, else the app keeps the user's
    /// name + email and keeps attributing comments/ratings after they leave.
    private let profileStore: any ProfileStoring
    private let revoker: (any SiwaRevoking)?

    /// The default `revoker` is the production SiwA-revoke client **when the
    /// Worker is configured** (DUT-98), else `nil` — so the app degrades
    /// gracefully (sign-in works, no exchange/revoke) until the owner fills
    /// `SiwaRevokeConfig.production` after `wrangler deploy`. Tests inject a fake
    /// (or `nil`). The default references only public symbols so it's valid on a
    /// public initializer.
    public init(
        store: any AppleAuthSessionStoring = KeychainAppleAuthSessionStore(),
        profileStore: any ProfileStoring = KeychainProfileStore(),
        revoker: (any SiwaRevoking)? = SiwaRevokeConfig.production.isConfigured
            ? SiwaRevokeClient(config: SiwaRevokeConfig.production) : nil
    ) {
        self.store = store
        self.profileStore = profileStore
        self.revoker = revoker
        // Seed from the store so a returning user lands signed-in. `try?` —
        // a Keychain read failure degrades to signed-out (guest), never a crash.
        self.session = try? store.load()
    }

    public var isSignedIn: Bool { session != nil }

    /// Apply a fresh Sign in with Apple credential: resolve name/email (carrying
    /// the first-auth values forward for the same user via
    /// ``AppleCredentialResolver``), persist, and publish **immediately** so
    /// sign-in feels instant. When `authorizationCode` is present and a revoke
    /// Worker is configured, the code is exchanged for a refresh token in the
    /// background and merged in (AC-46.6). The view extracts `(user, fullName,
    /// email, authorizationCode)` from the `ASAuthorizationAppleIDCredential`.
    public func applySignIn(
        userIdentifier: String,
        displayName: String?,
        email: String?,
        authorizationCode: String? = nil
    ) {
        let existing = try? store.load()
        let resolved = AppleCredentialResolver.resolve(
            userIdentifier: userIdentifier,
            credentialDisplayName: displayName,
            credentialEmail: email,
            existing: existing
        )
        // Carry an existing refresh token forward for the same user until the
        // exchange below yields a fresh one (a re-auth without a new code keeps
        // the prior token so deletion can still revoke).
        let carried = existing?.userIdentifier == userIdentifier ? existing?.refreshToken : nil
        let initial = AppleAuthSession(
            userIdentifier: resolved.userIdentifier,
            displayName: resolved.displayName,
            email: resolved.email,
            refreshToken: carried
        )
        try? store.save(initial)
        session = initial

        guard let authorizationCode, let revoker else { return }
        Task {
            guard let token = try? await revoker.exchange(authorizationCode: authorizationCode)
            else { return }
            // DUT-266: the exchange is async. If the user signed out / deleted /
            // signed in as someone else while it was in flight, don't resurrect
            // the torn-down session or persist a now-orphaned (never-revoked)
            // refresh token — that would re-open the DUT-217 5.1.1(v) gap.
            guard session?.userIdentifier == initial.userIdentifier else { return }
            let updated = AppleAuthSession(
                userIdentifier: initial.userIdentifier,
                displayName: initial.displayName,
                email: initial.email,
                refreshToken: token
            )
            try? store.save(updated)
            session = updated
        }
    }

    /// AC-46.3 — Sign Out: clear the local session and fall back to guest mode.
    /// (Sign out does NOT revoke — the user may sign back in; revocation is for
    /// account *deletion*.)
    public func signOut() async {
        try? store.clear()
        session = nil
        // DUT-217: clear the coupled UserProfile row too (no revoke — the user
        // may sign back in; revocation is for account *deletion*).
        try? await profileStore.clear()
    }

    /// AC-46.6 — in-app Delete Account (App Store Guideline 5.1.1(v)). Clears
    /// the local session immediately, then **revokes the Apple refresh token**
    /// via the DUT-98 Worker (best-effort, fire-and-forget with the captured
    /// token — a transient network failure still deletes locally; the token
    /// also expires). When no token was exchanged (no Worker configured), this
    /// is just the local clear.
    public func deleteAccount() async {
        let token = session?.refreshToken
        try? store.clear()
        session = nil
        // DUT-217: an explicit account deletion must not leave personal data on
        // device — clear the coupled UserProfile row too.
        try? await profileStore.clear()
        guard let token, let revoker else { return }
        try? await revoker.revoke(refreshToken: token)
    }
}

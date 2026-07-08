import DODSupport
import Foundation

#if canImport(UIKit)
import AuthenticationServices
#endif

/// DUT-635 — reacts to a **revoked / expired Apple credential** so a
/// signed-in user isn't stranded in a signed-in state forever after they
/// disable "Sign in with Apple" for the app in iOS Settings (or Apple
/// otherwise invalidates the credential).
///
/// Before DUT-635 the app persisted the ``AppleAuthSession`` at sign-in and
/// only ever tore it down on an explicit Sign Out / Delete. Apple's
/// `ASAuthorizationAppleIDProvider` exposes two signals we were ignoring:
///   1. `getCredentialState(forUserID:)` — poll on launch / foreground; a
///      `.revoked` / `.notFound` result means the stored session is dead.
///   2. `credentialRevokedNotification` — a live notification posted while the
///      app is running when the credential is revoked out from under it.
///
/// This type is a **pure orchestrator** with the platform lookup injected as a
/// closure, so the whole "revoked → clear session" behaviour is L1-testable
/// without `AuthenticationServices` (the macOS test build has no SiwA). The
/// production wiring (`makeProduction`) plugs in the real
/// `ASAuthorizationAppleIDProvider` lookup.
///
/// **App composition-root note.** `validateOnLaunchOrForeground()` and
/// `startObservingRevocation()` are meant to be called from the App target
/// (on `.active`/launch and once at startup respectively). This package can't
/// reach the App's scene lifecycle, so the App PR wires those calls;
/// see the PR description.
public struct AppleCredentialValidator: Sendable {

    /// The subset of `ASAuthorizationAppleIDProvider.CredentialState` this
    /// type acts on, mapped to a UIKit-free enum so the orchestration is
    /// testable on macOS. `.authorized` (and `.transferred`, which we treat as
    /// still-valid) leave the session untouched.
    public enum Status: Sendable, Equatable {
        case authorized
        /// The user disabled SiwA for the app in Settings, or Apple revoked it.
        case revoked
        /// No credential on file for this user id (e.g. deleted Apple ID).
        case notFound
    }

    private let sessionStore: any AppleAuthSessionStoring
    private let profileStore: any ProfileStoring
    private let guestIdentity: any GuestIdentityStoring
    private let revoker: (any SiwaRevoking)?
    private let onSessionCleared: (@Sendable () async -> Void)?
    /// Injected credential-state lookup: given a non-empty user id, resolve the
    /// current ``Status``. Nil-returning (or throwing) lookups are treated as
    /// inconclusive and leave the session intact — we only clear on a definite
    /// `.revoked` / `.notFound`.
    private let credentialStatus: @Sendable (String) async -> Status?

    public init(
        sessionStore: any AppleAuthSessionStoring,
        profileStore: any ProfileStoring,
        revoker: (any SiwaRevoking)?,
        guestIdentity: any GuestIdentityStoring = KeychainGuestIdentityStore(),
        onSessionCleared: (@Sendable () async -> Void)? = nil,
        credentialStatus: @escaping @Sendable (String) async -> Status?
    ) {
        self.sessionStore = sessionStore
        self.profileStore = profileStore
        self.revoker = revoker
        self.guestIdentity = guestIdentity
        self.onSessionCleared = onSessionCleared
        self.credentialStatus = credentialStatus
    }

    /// Poll the stored session's Apple credential and clear the local session
    /// when it's `.revoked` / `.notFound`. No-op when there's no session, when
    /// the session isn't Apple-issued (blank id), or when the lookup is
    /// inconclusive. Returns `true` iff a session was cleared, so the caller /
    /// tests can assert the reaction.
    ///
    /// Call on app launch and every foreground transition (`scenePhase ==
    /// .active`) from the App target.
    @discardableResult
    public func validateOnLaunchOrForeground() async -> Bool {
        guard let session = try? sessionStore.load() else { return false }
        // DUT-701 — the session model is provider-neutral and is reused for Sign
        // in with Google. Never poll a non-Apple session against Apple's
        // credential state: Apple returns `.notFound` for an id it never issued,
        // which would wrongly tear down every Google user's session.
        guard session.provider == .apple else { return false }
        let userID = session.userIdentifier
        guard !userID.isBlankAppleIdentifier else { return false }
        switch await credentialStatus(userID) {
        case .revoked, .notFound:
            await clearSession()
            return true
        case .authorized, .none:
            // Authorized, or an inconclusive lookup (offline / transient): keep
            // the session — never sign a user out on an ambiguous signal.
            return false
        }
    }

    /// Clear the local session immediately — used by the live
    /// `credentialRevokedNotification` observer, where the OS has already told
    /// us the credential is gone (no need to re-poll). Idempotent + best-effort.
    public func handleCredentialRevoked() async {
        guard (try? sessionStore.load()) != nil else { return }
        await clearSession()
    }

    /// Tear down the coupled session/profile/guest rows. Does NOT revoke the
    /// refresh token: the credential is already dead at Apple, so there's
    /// nothing to revoke, and this is a reaction (not a user-initiated Delete).
    /// Reuses ``ProfileEditView/performAccountTeardown(...)`` so the clearing
    /// logic stays in one place.
    private func clearSession() async {
        try? await ProfileEditView.performAccountTeardown(
            revoke: false,
            profileStore: profileStore,
            sessionStore: sessionStore,
            guestIdentity: guestIdentity,
            revoker: revoker
        )
        await onSessionCleared?()
    }
}

#if canImport(UIKit)
extension AppleCredentialValidator {

    /// Production wiring: resolve the credential state via the real
    /// `ASAuthorizationAppleIDProvider`. Maps `.authorized` / `.transferred` to
    /// ``Status/authorized`` (still valid), `.revoked` / `.notFound` to their
    /// namesakes, and any future case conservatively to `nil` (inconclusive —
    /// don't sign the user out on an unknown state).
    public static func makeProduction(
        sessionStore: any AppleAuthSessionStoring = KeychainAppleAuthSessionStore(),
        profileStore: any ProfileStoring,
        revoker: (any SiwaRevoking)? = SiwaRevokeConfig.production.isConfigured
            ? SiwaRevokeClient(config: SiwaRevokeConfig.production) : nil,
        onSessionCleared: (@Sendable () async -> Void)? = nil
    ) -> AppleCredentialValidator {
        AppleCredentialValidator(
            sessionStore: sessionStore,
            profileStore: profileStore,
            revoker: revoker,
            onSessionCleared: onSessionCleared,
            credentialStatus: { userID in
                // Use the completion-handler API (not the async `credentialState`
                // bridge): Apple delivers a non-nil error ALONGSIDE the
                // `.notFound` state, which makes the async/throwing form throw
                // and lose the `.notFound` we specifically need to react to. The
                // callback hands us the state directly regardless of the error.
                let state: ASAuthorizationAppleIDProvider.CredentialState =
                    await withCheckedContinuation { continuation in
                        ASAuthorizationAppleIDProvider()
                            .getCredentialState(forUserID: userID) { credentialState, _ in
                                continuation.resume(returning: credentialState)
                            }
                    }
                switch state {
                case .authorized, .transferred:
                    return .authorized
                case .revoked:
                    return .revoked
                case .notFound:
                    return .notFound
                @unknown default:
                    return nil
                }
            }
        )
    }

    /// Register a `credentialRevokedNotification` observer that clears the
    /// session the moment Apple posts it (the app is running). Returns the
    /// observer token; the App target retains it for the app's lifetime and
    /// removes it on teardown. The App PR performs this registration.
    public func startObservingRevocation() -> NSObjectProtocol {
        NotificationCenter.default.addObserver(
            forName: ASAuthorizationAppleIDProvider.credentialRevokedNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { await self.handleCredentialRevoked() }
        }
    }
}
#endif

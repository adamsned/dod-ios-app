#if canImport(UIKit)
import AuthenticationServices
import DODSupport
import SwiftUI

/// The native **Sign in with Apple** button for the profile-login surfaces —
/// the shared control that replaced the Settings ▸ Account sign-in button when
/// the entry moved onto the profile editor (DUT-189). On success it runs
/// ``AppleProfileSignIn`` (persist session + write profile + background
/// refresh-token exchange) and hands the host an ``AppleProfileSignIn/Outcome``
/// so it can fill its fields and dismiss. Scopes (`.fullName`, `.email`) +
/// `.black` styling + 44pt height match the former Settings button so sign-in
/// looks identical wherever it now appears.
///
/// The only thing here that touches `AuthenticationServices` is the button +
/// the credential-field extraction; the resolve/persist is the pure
/// ``AppleProfileSignIn`` (DODSupport-only), so it's L1-tested without UIKit.
public struct AppleProfileSignInButton: View {

    private let profileStore: any ProfileStoring
    private let onComplete: @MainActor (AppleProfileSignIn.Outcome) -> Void
    private let onError: (@MainActor (String) -> Void)?

    public init(
        profileStore: any ProfileStoring,
        onComplete: @MainActor @escaping (AppleProfileSignIn.Outcome) -> Void,
        onError: (@MainActor (String) -> Void)? = nil
    ) {
        self.profileStore = profileStore
        self.onComplete = onComplete
        self.onError = onError
    }

    public var body: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.fullName, .email]
        } onCompletion: { result in
            // DUT-636: a `.failure` was previously swallowed, leaving the user
            // staring at a button that did nothing. Distinguish a user-initiated
            // cancel (stay silent — they backed out on purpose) from a real
            // error (network, unknown), and surface the latter to the host.
            guard case .success(let authorization) = result else {
                if case .failure(let error) = result {
                    if let message = Self.userFacingErrorMessage(for: error) {
                        onError?(message)
                    }
                }
                return
            }
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential
            else { return }
            // Capture the credential fields up front (the credential isn't
            // Sendable) before hopping onto the sign-in task.
            let userIdentifier = credential.user
            // DUT-506: an empty / whitespace-only `credential.user` is not a real
            // sign-in — persisting it makes `hasSession` true for a phantom session
            // and collides across users in the resolver. Bail before running
            // `apply` / `onComplete` (which would flip `hasSession`), matching the
            // Google side where `GIDSignInProvider` drops an empty id to a silent
            // `.failed` no-op (DUT-285) rather than surfacing an error.
            guard !userIdentifier.isBlankAppleIdentifier else { return }
            let displayName = AppleCredentialResolver.displayName(from: credential.fullName)
            let email = credential.email
            let authorizationCode = credential.authorizationCode.flatMap {
                String(data: $0, encoding: .utf8)
            }
            let signIn = AppleProfileSignIn(profileStore: profileStore)
            Task { @MainActor in
                let outcome = await signIn.apply(
                    userIdentifier: userIdentifier,
                    displayName: displayName,
                    email: email,
                    authorizationCode: authorizationCode
                )
                onComplete(outcome)
            }
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 44)
        .accessibilityIdentifier("profile-sign-in-apple")
    }

    /// DUT-636 — classify a Sign in with Apple failure. Returns `nil` when the
    /// user simply canceled / dismissed the sheet (no error UI — that's a
    /// deliberate back-out, matching the empty-credential silent no-op above),
    /// and a short user-facing message for a real failure the host should
    /// surface. `unknown` is bucketed with cancellation: the system reports a
    /// user-driven dismissal as `.unknown` on some OS versions, so treating it
    /// as an error would nag users who just changed their mind.
    static func userFacingErrorMessage(for error: any Error) -> String? {
        guard let authError = error as? ASAuthorizationError else {
            return "Couldn't Sign In With Apple. Try Again."
        }
        switch authError.code {
        case .canceled, .unknown:
            return nil
        case .failed, .invalidResponse, .notHandled, .notInteractive:
            return "Couldn't Sign In With Apple. Try Again."
        @unknown default:
            return "Couldn't Sign In With Apple. Try Again."
        }
    }
}
#endif

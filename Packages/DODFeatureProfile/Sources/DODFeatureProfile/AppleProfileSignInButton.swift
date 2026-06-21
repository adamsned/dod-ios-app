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

    public init(
        profileStore: any ProfileStoring,
        onComplete: @MainActor @escaping (AppleProfileSignIn.Outcome) -> Void
    ) {
        self.profileStore = profileStore
        self.onComplete = onComplete
    }

    public var body: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.fullName, .email]
        } onCompletion: { result in
            guard case .success(let authorization) = result,
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential
            else { return }
            // Capture the credential fields up front (the credential isn't
            // Sendable) before hopping onto the sign-in task.
            let userIdentifier = credential.user
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
}
#endif

import AuthenticationServices
import DODDesignSystem
import DODSupport
import SwiftUI

// US-46 / AC-46.2..46.4 (T-794, DUT-16 Phase a) — the Settings → Account
// section: Sign in with Apple, a signed-in identity row, Sign Out, and the
// in-app Delete Account affordance (App Store Guideline 5.1.1(v)).
//
// Extracted from `SettingsView.swift` (like `SettingsView+Shop.swift` /
// `SettingsView+Voice.swift`) so the host stays under SwiftLint's 400-line
// `file_length` cap. Self-contained: it owns an ``AccountViewModel`` seeded
// from the production Keychain store by default, overridable for previews /
// snapshots / UI tests.
//
// Guest mode (US-15) stays the default — signing in is optional and unlocks a
// durable comment/rating identity (and, later, cross-device state). The
// credential→session merge is the pure `AppleCredentialResolver` (DODSupport),
// so the only thing here that touches `AuthenticationServices` is the button +
// the credential field extraction.

// MARK: - Account section

/// Renders the Settings "Account" `Section`. Signed out → a `SignInWithApple`
/// button + an "optional" caption; signed in → the identity (name / email) +
/// Sign Out + Delete Account.
struct AccountSection: View {

    @State private var viewModel: AccountViewModel

    /// Inject a view-model (snapshots / UI tests / previews); production callers
    /// use the default, which wires the Keychain-backed store.
    init(viewModel: AccountViewModel = AccountViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Section {
            if viewModel.isSignedIn {
                signedInRows
            } else {
                signInButton
            }
        } header: {
            Text("Account")
                .dodFont(DODType.heading)
                .foregroundStyle(DODColor.label)
        } footer: {
            Text(footerText)
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
        }
        .listRowBackground(DODColor.surfaceElevated)
    }

    private var footerText: String {
        viewModel.isSignedIn
            ? "Signing out returns you to guest mode. Your saved recipes stay on this device."
            : "Optional — you can browse, save, and comment as a guest without signing in."
    }

    // MARK: Signed-out

    /// AC-46.2 — the native Sign in with Apple button. On success we extract the
    /// stable user id + (first-auth-only) name/email and hand them to the
    /// view-model, which resolves + persists the session. Cancellation /
    /// failure is a no-op (the user stays in guest mode).
    private var signInButton: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.fullName, .email]
        } onCompletion: { result in
            guard case .success(let authorization) = result,
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential
            else { return }
            viewModel.applySignIn(
                userIdentifier: credential.user,
                displayName: AppleCredentialResolver.displayName(from: credential.fullName),
                email: credential.email,
                // The one-time authorization code — exchanged server-side for a
                // refresh token so Delete Account can revoke it (DUT-98).
                authorizationCode: credential.authorizationCode.flatMap {
                    String(data: $0, encoding: .utf8)
                }
            )
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 44)
        .accessibilityIdentifier("settings-button-sign-in-apple")
    }

    // MARK: Signed-in

    @ViewBuilder
    private var signedInRows: some View {
        VStack(alignment: .leading, spacing: DODSpacing.xxs) {
            Text(viewModel.session?.displayName ?? "Signed in with Apple")
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.label)
            if let email = viewModel.session?.email {
                Text(email)
                    .dodFont(DODType.detail)
                    .foregroundStyle(DODColor.labelSecondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("settings-account-identity")

        Button {
            viewModel.signOut()
        } label: {
            Text("Sign Out")
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.accent)
        }
        .accessibilityIdentifier("settings-button-sign-out")

        // AC-46.3 — in-app account deletion (App Store Guideline 5.1.1(v)).
        Button(role: .destructive) {
            viewModel.deleteAccount()
        } label: {
            Text("Delete Account")
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.burntOrange)
        }
        .accessibilityIdentifier("settings-button-delete-account")
    }
}

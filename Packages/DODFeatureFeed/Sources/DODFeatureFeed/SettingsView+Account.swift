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
                signedOutPointer
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
            : "Optional. You can browse, save, and comment as a guest without signing in."
    }

    // MARK: Signed-out

    /// DUT-189 — the Sign in with Apple button moved to the profile editor
    /// (``AppleProfileSignInButton``, reached via Settings ▸ Profile / the iPad
    /// sidebar Profile / the recipe ratings gate). When signed out, the Account
    /// section points there rather than hosting the button; signing in there
    /// persists the same ``AppleAuthSession`` this section reads for its
    /// signed-in rows.
    private var signedOutPointer: some View {
        Text("Sign in with Apple from your Profile to comment and rate as yourself.")
            .dodFont(DODType.body)
            .foregroundStyle(DODColor.labelSecondary)
            .accessibilityIdentifier("settings-account-signin-pointer")
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

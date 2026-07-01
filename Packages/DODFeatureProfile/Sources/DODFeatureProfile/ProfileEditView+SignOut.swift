import DODDesignSystem
import SwiftUI

// Sign Out + Delete Profile sections, extracted from `ProfileEditView.swift` so
// that file stays under the SwiftLint 400-line `file_length` cap after the
// DUT-416 (view/edit mode) + DUT-417 (stats) additions.
extension ProfileEditView {

    @ViewBuilder
    var signOutSection: some View {
        // Sign Out + Delete Profile are intentionally rendered as two
        // separate buttons in two separate sections (Form gives each a
        // visual gap), per the locked decision: both ship in Phase a
        // because App Store 5.1.1(v) requires an explicit Delete
        // Account, and "Sign Out" is the friendlier wording for the
        // common case. Local-only v1 — identical behavior. When DUT-16
        // adds backend state, the two diverge.
        // DUT-281 — also show when a session exists without a profile, so a
        // signed-in-but-profile-less user can still Sign Out / Delete (revoke).
        if existingProfile != nil || hasSession {
            Section {
                Button {
                    // DUT-429 — confirm first (see the `.alert` in
                    // ProfileEditView), matching the guarded Delete button.
                    showSignOutConfirmation = true
                } label: {
                    Text("Sign Out")
                        .dodFont(DODType.body)
                        .foregroundStyle(DODColor.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityIdentifier("profile-edit-signout")
            }
            .listRowBackground(DODColor.surfaceElevated)
            // DUT-429 — Sign Out is a destructive local teardown (clears the
            // guest-identity prefill too), so confirm it like Delete rather
            // than acting on a single unguarded tap.
            .alert("Sign out of your profile?", isPresented: $showSignOutConfirmation) {
                Button("Sign Out", role: .destructive) {
                    Task { await handleSignOut() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(
                    "This clears your saved name and email on this device. "
                        + "Future comments will be attributed to a guest."
                )
            }

            Section {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Text("Delete Profile")
                        .dodFont(DODType.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityIdentifier("profile-edit-delete")
            }
            .listRowBackground(DODColor.surfaceElevated)
        }
    }
}

import DODDesignSystem
import SwiftUI

/// Push destination for editing (or creating) the on-device user
/// profile. Reached from ``ProfileSection``; back-stack-pushes from
/// `SettingsView`.
///
/// Three top-level surfaces:
///
/// 1. **Identity fields** — Display Name + Email TextFields. Both
///    required (Done button disabled until both non-empty + email
///    matches the basic regex per ``UserProfile/validateEmail(_:)``).
/// 2. **Profile Picture row** (Phase a stub) — labels the section with
///    the current avatar trailing. Tap does nothing yet — the photo
///    picker + crop UI is Phase b's scope. A `// TODO: Phase b` comment
///    marks the wire-in point.
/// 3. **Sign Out** + **Delete Profile** buttons — both clear the
///    Keychain entry (identical behavior for local-only v1 per the
///    locked decision). The Delete button is `Button(role:
///    .destructive)` + fronts a confirmation alert per App Store
///    5.1.1(v); Sign Out flips through without the alert (friendlier
///    everyday UX). When DUT-16 lands and adds backend state, these
///    two diverge — sign-out keeps server data, delete nukes it.
///
/// Toolbar:
/// - **Cancel** (top-left) — dismisses without saving.
/// - **Done** (top-right) — saves the profile via
///   ``ProfileStoring/save(_:)`` and dismisses. Disabled until the form
///   validates.
///
/// Spec trace: US-44 AC-44.2, AC-44.3, AC-44.4; CL-136.
public struct ProfileEditView: View {

    let store: any ProfileStoring
    let existingProfile: UserProfile?
    /// Closure invoked after a successful save / sign-out / delete so
    /// the parent (`SettingsViewModel`) can refresh its cached
    /// `profile` property. Matches the cache-clear feedback callback
    /// pattern the rest of `SettingsView` uses.
    let onProfileChanged: @MainActor () async -> Void

    @State private var displayName: String = ""
    @State private var email: String = ""
    @State private var emailValidationError: String?
    @State private var saveError: String?
    @State private var showDeleteConfirmation = false
    @State private var isSubmitting = false

    @Environment(\.dismiss) private var dismiss

    public init(
        store: any ProfileStoring,
        existingProfile: UserProfile?,
        onProfileChanged: @MainActor @escaping () async -> Void
    ) {
        self.store = store
        self.existingProfile = existingProfile
        self.onProfileChanged = onProfileChanged
    }

    public var body: some View {
        Form {
            identitySection
            photoSection
            signOutSection
            if let saveError {
                Section {
                    Text(saveError)
                        .dodFont(DODType.caption)
                        .foregroundStyle(DODColor.labelSecondary)
                }
                .listRowBackground(DODColor.surfaceElevated)
            }
        }
        .scrollContentBackground(.hidden)
        .background(DODColor.surface)
        .navigationTitle(existingProfile == nil ? "New Profile" : "Profile")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar { toolbarContent }
        .alert("Delete your profile?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task { await handleClear() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove your display name, email, and any future comments will be attributed to a guest.")
        }
        .onAppear {
            // Seed the fields from the existing profile (if any) only
            // once — re-applying on every body recompute would clobber
            // the user's in-flight edits.
            if let existingProfile, displayName.isEmpty, email.isEmpty {
                displayName = existingProfile.displayName
                email = existingProfile.email
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var identitySection: some View {
        Section {
            TextField("Display name", text: $displayName)
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.label)
                .textContentType(.name)
                .accessibilityIdentifier("profile-edit-displayname")
                #if os(iOS)
                .autocapitalization(.words)
                #endif

            TextField("Email", text: $email)
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.label)
                .textContentType(.emailAddress)
                .accessibilityIdentifier("profile-edit-email")
                #if os(iOS)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .autocorrectionDisabled(true)
                #endif
        } footer: {
            if let emailValidationError {
                Text(emailValidationError)
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
            }
        }
        .listRowBackground(DODColor.surfaceElevated)
    }

    @ViewBuilder
    private var photoSection: some View {
        Section {
            // TODO: Phase b (DUT-36) — wire up PhotosPicker + crop UI.
            // Tapping the row in Phase a is intentionally a no-op; the
            // section exists so the visual layout is locked + the
            // photo flow has a documented home when it lands.
            HStack(spacing: DODSpacing.md) {
                Text("Profile Picture")
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.label)
                Spacer(minLength: 0)
                ProfilePhotoView(
                    profile: previewProfile,
                    diameter: 44
                )
            }
            .accessibilityIdentifier("profile-edit-photo")
        } footer: {
            Text("Photo upload comes in the next update.")
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
        }
        .listRowBackground(DODColor.surfaceElevated)
    }

    @ViewBuilder
    private var signOutSection: some View {
        // Sign Out + Delete Profile are intentionally rendered as two
        // separate buttons in two separate sections (Form gives each a
        // visual gap), per the locked decision: both ship in Phase a
        // because App Store 5.1.1(v) requires an explicit Delete
        // Account, and "Sign Out" is the friendlier wording for the
        // common case. Local-only v1 — identical behavior. When DUT-16
        // adds backend state, the two diverge.
        if existingProfile != nil {
            Section {
                Button {
                    Task { await handleClear() }
                } label: {
                    Text("Sign Out")
                        .dodFont(DODType.body)
                        .foregroundStyle(DODColor.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityIdentifier("profile-edit-signout")
            }
            .listRowBackground(DODColor.surfaceElevated)

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

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                dismiss()
            }
            .accessibilityIdentifier("profile-edit-cancel")
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Done") {
                Task { await handleSave() }
            }
            .disabled(!isFormValid || isSubmitting)
            .accessibilityIdentifier("profile-edit-done")
        }
    }

    // MARK: - State

    /// `true` when display name + email are both non-whitespace AND
    /// the email matches the basic regex. Drives the Done button.
    private var isFormValid: Bool {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }
        return (try? UserProfile.validateEmail(email)) != nil
    }

    /// A live preview profile used by the photo row's avatar — so the
    /// initial-letter circle updates as the user types their name
    /// before they tap Done.
    private var previewProfile: UserProfile {
        UserProfile(
            id: existingProfile?.id ?? UUID(),
            displayName: displayName,
            email: email,
            photoFilename: existingProfile?.photoFilename
        )
    }

    // MARK: - Actions

    @MainActor
    private func handleSave() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        emailValidationError = nil
        saveError = nil

        do {
            let cleanedName = try UserProfile.validateDisplayName(displayName)
            let cleanedEmail = try UserProfile.validateEmail(email)
            let profile = UserProfile(
                id: existingProfile?.id ?? UUID(),
                displayName: cleanedName,
                email: cleanedEmail,
                photoFilename: existingProfile?.photoFilename
            )
            try await store.save(profile)
            await onProfileChanged()
            dismiss()
        } catch let error as UserProfile.ValidationError {
            switch error {
            case .displayNameEmpty:
                saveError = "Add your name to save your profile."
            case .emailEmpty:
                emailValidationError = "Add your email to save your profile."
            case .emailInvalid:
                emailValidationError = "Enter a valid email address."
            }
        } catch {
            saveError = "Couldn't save your profile — try again."
        }
    }

    @MainActor
    private func handleClear() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await store.clear()
            await onProfileChanged()
            dismiss()
        } catch {
            saveError = "Couldn't sign out — try again."
        }
    }
}

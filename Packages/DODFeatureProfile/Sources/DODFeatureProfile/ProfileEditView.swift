import DODDesignSystem
import SwiftUI

#if canImport(UIKit)
import PhotosUI
import UIKit
#endif

/// Push destination for editing (or creating) the on-device user
/// profile. Reached from ``ProfileSection``; back-stack-pushes from
/// `SettingsView`.
///
/// Three top-level surfaces:
///
/// 1. **Identity fields** — Display Name + Email TextFields. Both
///    required (Save button disabled until both non-empty + email
///    matches the basic regex per ``UserProfile/validateEmail(_:)``).
/// 2. **Profile Picture row** — labels the section with the current
///    avatar trailing. Tap (no photo) → presents ``ProfilePhotoPicker``
///    (Apple's privacy-preserving `PhotosPicker` — no permission
///    prompt). Tap (photo exists) → confirmation dialog with Replace
///    Photo / Remove Photo / Cancel. On crop completion the new file
///    name is updated in-flight; on Replace the previous file is
///    cleared post-save (write-then-clear-old so a mid-flow failure
///    leaves the old file intact). Phase b — CL-137 / AC-44.3 / 8 / 9.
/// 3. **Sign Out** + **Delete Profile** buttons — both clear the
///    Keychain entry (identical behavior for local-only v1 per the
///    locked decision). The Delete button is `Button(role:
///    .destructive)` + fronts a confirmation alert per App Store
///    5.1.1(v); Sign Out flips through without the alert (friendlier
///    everyday UX). When DUT-16 lands and adds backend state, these
///    two diverge — sign-out keeps server data, delete nukes it.
///
/// Toolbar (T-743 / CL-140 / AC-44.16):
/// - **Back chevron** (top-left) — custom `Image(systemName:
///   "chevron.left")` button; system back is suppressed via
///   `.navigationBarBackButtonHidden(true)`. When `isDirty` (display
///   name / email / photo changed since `.onAppear` snapshots), tap
///   fronts a `.confirmationDialog("You have unsaved changes")` with
///   "Continue Editing" + "Leave Without Saving" (destructive). When
///   clean, taps dismiss directly. Replaces the pre-T-743 "Cancel"
///   button.
/// - **Save** (top-right) — saves the profile via
///   ``ProfileStoring/save(_:)`` and dismisses. Disabled until the form
///   validates. Renamed from "Done" in T-743 (clearer about what the
///   button does).
///
/// **Modal-sheet drag-down guard.** `.interactiveDismissDisabled(isDirty)`
/// blocks the swipe-to-dismiss gesture in the Phase c gate-CTA modal-
/// sheet context when the form is dirty, so the user must route
/// through the back chevron (and therefore see the dialog). No-op on
/// push (push has no swipe-down).
///
/// **Sign Out + Delete Profile bypass the unsaved-changes dialog by
/// construction** — both buttons call `handleClear()` (clear + dismiss)
/// directly without consulting `isDirty` or `showLeaveConfirmation`.
/// Delete Profile's existing destructive alert "Delete your profile?"
/// is preserved and is distinct from the new unsaved-changes dialog.
///
/// Spec trace: US-44 AC-44.2, AC-44.3, AC-44.4, AC-44.8, AC-44.9,
/// AC-44.16; CL-136, CL-137, CL-140.
public struct ProfileEditView: View {

    let store: any ProfileStoring
    let existingProfile: UserProfile?
    /// Closure invoked after a successful save / sign-out / delete so
    /// the parent (`SettingsViewModel`) can refresh its cached
    /// `profile` property. Matches the cache-clear feedback callback
    /// pattern the rest of `SettingsView` uses.
    let onProfileChanged: @MainActor () async -> Void
    #if canImport(UIKit)
    /// Phase b — Photo store collaborator used by the Profile Picture
    /// row to persist + clear the on-disk JPG. `nil` for previews and
    /// test hosts that don't wire one — the row falls back to the
    /// Phase a stub behavior in that case (the picker still wires up
    /// but the save step gracefully no-ops). UIKit-gated because the
    /// store returns ``UIImage``.
    let photoStore: (any ProfilePhotoStoring)?
    #endif

    @State var displayName: String = ""
    @State var email: String = ""
    @State private var emailValidationError: String?
    @State var saveError: String?
    @State private var showDeleteConfirmation = false
    @State private var isSubmitting = false
    /// T-743 / CL-140 / AC-44.16 — snapshots of the initial field values
    /// captured on `.onAppear` so the back-button intercept can compute
    /// `isDirty`. Seeded once (when their `nil`/empty seed value
    /// indicates the snapshot hasn't been taken yet); subsequent
    /// re-renders don't clobber them so the dirty-state comparison
    /// stays honest across the user's in-flight edits.
    @State private var initialDisplayName: String = ""
    @State private var initialEmail: String = ""
    @State private var initialPhotoFilename: String?
    /// T-743 / CL-140 / AC-44.16 — `true` while the unsaved-changes
    /// confirmationDialog is presented. Set by the custom back chevron
    /// when `isDirty`; cleared by either dialog button.
    @State private var showLeaveConfirmation = false
    /// T-743 / CL-140 / AC-44.16 — set once `.onAppear` has captured
    /// the initial-value snapshots. Prevents a second `.onAppear` (e.g.
    /// after a sheet-presentation re-mount) from re-seeding the
    /// snapshots from already-edited field values.
    @State private var didCaptureInitialValues = false
    /// Phase b — the in-flight `photoFilename`. Seeded from
    /// `existingProfile?.photoFilename` on first appear; updated when
    /// the user crops a new photo (Replace / first upload) or removes
    /// the existing one. Distinct from `existingProfile?.photoFilename`
    /// so we can compute the "did this filename change" diff in
    /// ``handleSave()`` + ``clearPreviousPhotoIfReplaced(...)``.
    @State var inFlightPhotoFilename: String?
    /// Set to the filename of the previously-saved photo when the user
    /// replaces it — cleared post-save so a mid-flow failure leaves
    /// the previous file intact (write-then-clear-old per CL-137).
    @State var photoFilenameToClearOnSave: String?
    #if canImport(UIKit)
    /// Phase b — `PhotosPicker` selection binding. Becomes non-nil
    /// when the user picks an image; `.onChange` then loads its bytes
    /// and presents the crop sheet.
    @State var pickerSelection: PhotosPickerItem?
    /// Phase b — Image handed to ``ProfilePhotoCropView``. Becomes
    /// non-nil when the picker selection's `loadTransferable` resolves,
    /// driving the crop sheet's identifiable-item presentation.
    @State var cropCandidate: CropCandidate?
    /// Phase b — Whether the Replace / Remove / Cancel confirmation
    /// dialog is showing (true when the user taps the row + a photo
    /// already exists).
    @State var showPhotoActionDialog = false
    /// Whether the `PhotosPicker` is showing (driven by the row tap
    /// when no photo exists OR by the Replace branch of the action
    /// dialog).
    @State var isPickerPresented = false
    #endif

    @Environment(\.dismiss) private var dismiss

    #if canImport(UIKit)
    public init(
        store: any ProfileStoring,
        existingProfile: UserProfile?,
        onProfileChanged: @MainActor @escaping () async -> Void,
        photoStore: (any ProfilePhotoStoring)? = nil
    ) {
        self.store = store
        self.existingProfile = existingProfile
        self.onProfileChanged = onProfileChanged
        self.photoStore = photoStore
    }
    #else
    public init(
        store: any ProfileStoring,
        existingProfile: UserProfile?,
        onProfileChanged: @MainActor @escaping () async -> Void
    ) {
        self.store = store
        self.existingProfile = existingProfile
        self.onProfileChanged = onProfileChanged
    }
    #endif

    #if canImport(UIKit)
    /// Identifiable wrapper around the picked image so we can drive a
    /// `.sheet(item:)` presentation by the image itself (rather than a
    /// `Bool` + a separate optional state variable).
    struct CropCandidate: Identifiable {
        let id = UUID()
        let image: UIImage
    }
    #endif

    public var body: some View {
        Form {
            identitySection
            profileEditPhotoSection
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
        .navigationBarBackButtonHidden(true)
        #endif
        .toolbar { toolbarContent }
        // T-743 / CL-140 / AC-44.16 — prevent drag-to-dismiss past
        // unsaved changes when presented as a modal sheet (Phase c
        // gate-CTA path). No-op on push (push has no swipe-down
        // gesture); safe to apply unconditionally.
        .interactiveDismissDisabled(isDirty)
        .alert("Delete your profile?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task { await handleClear() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove your display name, email, and any future comments will be attributed to a guest.")
        }
        // T-743 / CL-140 / AC-44.16 — the custom back chevron taps into
        // this dialog when the form is dirty. Sign Out + Delete Profile
        // bypass by construction (their button closures call
        // `handleClear()` + `dismiss()` directly without consulting
        // `isDirty` or setting `showLeaveConfirmation`).
        .confirmationDialog(
            "You have unsaved changes",
            isPresented: $showLeaveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Continue Editing") {
                showLeaveConfirmation = false
            }
            Button("Leave Without Saving", role: .destructive) {
                showLeaveConfirmation = false
                dismiss()
            }
        }
        .profileEditPhotoFlow(view: self)
        .onAppear {
            // Seed the fields from the existing profile (if any) only
            // once — re-applying on every body recompute would clobber
            // the user's in-flight edits.
            if let existingProfile, displayName.isEmpty, email.isEmpty {
                displayName = existingProfile.displayName
                email = existingProfile.email
            }
            if inFlightPhotoFilename == nil {
                inFlightPhotoFilename = existingProfile?.photoFilename
            }
            // T-743 / CL-140 — capture the initial-value snapshots for
            // dirty-state tracking. Guarded by `didCaptureInitialValues`
            // so a second `.onAppear` (from a re-mount) doesn't re-seed
            // the snapshots from already-edited values.
            if !didCaptureInitialValues {
                initialDisplayName = existingProfile?.displayName ?? ""
                initialEmail = existingProfile?.email ?? ""
                initialPhotoFilename = existingProfile?.photoFilename
                didCaptureInitialValues = true
            }
        }
    }

    // MARK: - Dirty state (T-743 / CL-140 / AC-44.16)

    /// `true` when the user has edited the display name, email, or
    /// photo since the form's initial-value snapshots were captured on
    /// `.onAppear`. Drives the back-chevron's intercept logic +
    /// `.interactiveDismissDisabled(...)` for the modal-sheet path.
    /// Delegates to the pure static helper so the L1 test suite can
    /// pin the four combinations (clean / name-dirty / email-dirty /
    /// photo-dirty) without spinning up a view host.
    var isDirty: Bool {
        Self.computeIsDirty(
            displayName: displayName,
            initialDisplayName: initialDisplayName,
            email: email,
            initialEmail: initialEmail,
            photoFilename: inFlightPhotoFilename,
            initialPhotoFilename: initialPhotoFilename
        )
    }

    /// Pure helper that computes the dirty state from the form values
    /// + the snapshots. `static` so the L1 test suite can pin the
    /// truth table without a view host.
    ///
    /// Truth table:
    /// - All three pairs equal → clean (`false`).
    /// - Any single pair differs → dirty (`true`).
    /// - Two or three pairs differ → dirty (`true`).
    ///
    /// Photo comparison uses optional equality — `nil == nil` is
    /// clean; `nil` vs a populated filename (or vice versa) is dirty.
    public static func computeIsDirty(
        displayName: String,
        initialDisplayName: String,
        email: String,
        initialEmail: String,
        photoFilename: String?,
        initialPhotoFilename: String?
    ) -> Bool {
        displayName != initialDisplayName
            || email != initialEmail
            || photoFilename != initialPhotoFilename
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

    /// T-743 / CL-140 / AC-44.16 — `.topBarLeading` carries a custom
    /// back chevron (no text) that intercepts dismissal when `isDirty`
    /// to front the `.confirmationDialog("You have unsaved changes")`.
    /// The system back button is suppressed via
    /// `.navigationBarBackButtonHidden(true)` on the view body so the
    /// chevron is the only leading affordance. Replaces the pre-T-743
    /// "Cancel" button. The trailing `.confirmationAction` button is
    /// renamed `Done` → `Save` (action / disabled state unchanged); the
    /// accessibility identifier flips to `"profile-edit-save"` so the
    /// contract matches the visible label.
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        #if os(iOS)
        ToolbarItem(placement: .topBarLeading) {
            Button {
                if isDirty {
                    showLeaveConfirmation = true
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel("Back")
            .accessibilityIdentifier("profile-edit-back")
        }
        #else
        ToolbarItem(placement: .cancellationAction) {
            Button {
                if isDirty {
                    showLeaveConfirmation = true
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel("Back")
            .accessibilityIdentifier("profile-edit-back")
        }
        #endif
        ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
                Task { await handleSave() }
            }
            .disabled(!isFormValid || isSubmitting)
            .accessibilityIdentifier("profile-edit-save")
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
                photoFilename: inFlightPhotoFilename
            )
            try await store.save(profile)
            #if canImport(UIKit)
            // Phase b — clear the previous photo file only after the
            // Keychain row has been updated with the new filename, so
            // a mid-flow save failure leaves the previous photo intact
            // (the new one is also on disk but unreferenced; orphans
            // are tolerable, half-overwritten primary photos are not).
            if let staleFilename = photoFilenameToClearOnSave {
                try? await photoStore?.clear(filename: staleFilename)
                photoFilenameToClearOnSave = nil
            }
            #endif
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
            // The store's `clear()` is amended in Phase b (AC-44.9) to
            // also delete the on-disk photo file, so we don't have to
            // call `photoStore?.clear(filename:)` here separately.
            try await store.clear()
            await onProfileChanged()
            dismiss()
        } catch {
            saveError = "Couldn't sign out — try again."
        }
    }

    // MARK: - Phase b — Photo handlers
    //
    // The photo-pipeline handlers (`loadPickedImage`, `handleCroppedImage`,
    // `handleRemovePhoto`) live in `ProfileEditView+Photo.swift` so this
    // file stays under the SwiftLint file_length + type_body_length caps.
    // The cross-file split is why several Phase b `@State` vars above
    // are declared without a `private` access modifier.
}

import DODDesignSystem
import SwiftUI

// T-743 / CL-140 / AC-44.16 — dirty-state machinery + toolbar content
// extracted from ``ProfileEditView``'s main file so the struct body +
// the file as a whole stay under SwiftLint's `type_body_length` +
// `file_length` caps after the dirty-state and back-chevron additions.
//
// What lives here:
// - ``ProfileEditView/isDirty`` — computed property delegating to the
//   static helper.
// - ``ProfileEditView/computeIsDirty(...)`` — pure static helper so the
//   L1 test suite can pin the four combinations (clean / name-dirty /
//   email-dirty / photo-dirty) without spinning up a view host.
// - ``ProfileEditView/toolbarContent`` — custom back chevron + Save
//   toolbar content. The chevron intercepts dismissal when `isDirty` to
//   front the `.confirmationDialog("You have unsaved changes")`; the
//   Save button preserves the pre-T-743 confirmation-action behavior
//   (action / disabled state / accessibility identifier).
//
// Spec trace: US-44 AC-44.16; CL-140.

extension ProfileEditView {

    // MARK: - Dirty state

    /// `true` when the user has edited the display name, email, or
    /// photo since the form's initial-value snapshots were captured on
    /// `.onAppear`. Drives the back-chevron's intercept logic +
    /// `.interactiveDismissDisabled(...)` for the modal-sheet path.
    /// Delegates to the pure static helper so the L1 test suite can
    /// pin the four combinations (clean / name-dirty / email-dirty /
    /// photo-dirty) without spinning up a view host.
    var isDirty: Bool {
        Self.computeIsDirty(
            displayName: (current: displayName, initial: initialDisplayName),
            email: (current: email, initial: initialEmail),
            photoFilename: (current: inFlightPhotoFilename, initial: initialPhotoFilename)
        )
    }

    /// Pure helper that computes the dirty state from the form values
    /// + the snapshots, expressed as three (current, initial) pairs
    /// (one per field). `static` so the L1 test suite can pin the
    /// truth table without a view host. Pair-shape rather than 6 flat
    /// args so the call site reads as "these are the three
    /// (now, then) comparisons" and stays under SwiftLint's
    /// `function_parameter_count` cap.
    ///
    /// Truth table:
    /// - All three pairs equal → clean (`false`).
    /// - Any single pair differs → dirty (`true`).
    /// - Two or three pairs differ → dirty (`true`).
    ///
    /// Photo comparison uses optional equality — `nil == nil` is
    /// clean; `nil` vs a populated filename (or vice versa) is dirty.
    public static func computeIsDirty(
        displayName: (current: String, initial: String),
        email: (current: String, initial: String),
        photoFilename: (current: String?, initial: String?)
    ) -> Bool {
        displayName.current != displayName.initial
            || email.current != email.initial
            || photoFilename.current != photoFilename.initial
    }

    // MARK: - View / edit mode (DUT-416 / CL-291)

    /// Inline navigation title: "New Profile" while setting up, "Edit Profile"
    /// while editing an existing one, "Profile" in read-only view mode.
    /// Delegates to the pure static helper so the L1 suite can pin the contract.
    var navigationTitleText: String {
        Self.navigationTitle(hasExistingProfile: existingProfile != nil, isEditing: isEditing)
    }

    /// Pure helper for ``navigationTitleText`` — `static` so the L1 test suite
    /// can pin the three states without a view host. No existing profile → always
    /// "New Profile" (the setup flow is always editing); an existing profile →
    /// "Edit Profile" while editing, "Profile" in read-only view mode.
    public static func navigationTitle(hasExistingProfile: Bool, isEditing: Bool) -> String {
        guard hasExistingProfile else { return "New Profile" }
        return isEditing ? "Edit Profile" : "Profile"
    }

    /// DUT-416 — "Cancel" tapped while editing an existing profile. With unsaved
    /// edits, front the confirmation dialog (its "Leave Without Saving" action
    /// reverts + drops to view mode); otherwise drop to view mode directly.
    func cancelEditing() {
        if isDirty {
            showLeaveConfirmation = true
        } else {
            exitEditMode()
        }
    }

    /// DUT-416 — revert the in-flight fields + photo to the captured snapshots
    /// and return to read-only view mode. The photo *files* written this session
    /// are cleaned up separately by `discardUnsavedPhotoFiles()` (DUT-353) before
    /// this runs; here we just reset the in-flight references the view reads.
    func exitEditMode() {
        displayName = initialDisplayName
        email = initialEmail
        inFlightPhotoFilename = initialPhotoFilename
        // DUT-693 PR4 — clear any non-blocking save/photo-degradation footer so a
        // stale "Couldn't save the original photo…" message doesn't linger into
        // read-only view mode after the user backs out of editing.
        saveError = nil
        isEditing = false
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
    ///
    /// DUT-416 — the leading + trailing items are now mode-aware: view mode
    /// shows a plain back chevron + "Edit Profile"; editing an existing profile
    /// shows "Cancel" + "Save"; the new-profile setup flow keeps the original
    /// dirty-aware back chevron + "Save".
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        #if os(iOS)
        ToolbarItem(placement: .topBarLeading) {
            leadingToolbarButton
        }
        #else
        ToolbarItem(placement: .cancellationAction) {
            leadingToolbarButton
        }
        #endif
        ToolbarItem(placement: .confirmationAction) {
            trailingToolbarButton
        }
    }

    /// Leading item: "Cancel" while editing an existing profile (reverts to view
    /// mode); the dirty-aware back chevron otherwise (view mode dismisses
    /// directly since nothing is dirty; new-profile setup keeps the dialog).
    @ViewBuilder
    private var leadingToolbarButton: some View {
        if isEditing && existingProfile != nil {
            Button("Cancel") { cancelEditing() }
                .accessibilityIdentifier("profile-edit-cancel")
        } else {
            backChevronButton
        }
    }

    /// Trailing item: "Save" while editing, "Edit Profile" in read-only view
    /// mode (enters edit mode for an existing profile).
    @ViewBuilder
    private var trailingToolbarButton: some View {
        if isEditing {
            saveButton
        } else {
            Button("Edit Profile") { isEditing = true }
                .accessibilityIdentifier("profile-edit-edit")
        }
    }

    /// The custom back chevron. Intercepts dismissal when `isDirty` to
    /// front the `.confirmationDialog`; otherwise dismisses directly.
    private var backChevronButton: some View {
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

    /// The trailing `Save` button. Action / disabled state are
    /// unchanged from the pre-T-743 "Done" button — only the label and
    /// accessibility identifier flipped.
    private var saveButton: some View {
        Button("Save") {
            Task { await handleSave() }
        }
        // DUT-693 PR4 — also disable when nothing changed (`!isDirty`) so a
        // redundant tap doesn't trigger another Keychain write.
        .disabled(!isFormValid || isSubmitting || !isDirty)
        .accessibilityIdentifier("profile-edit-save")
    }
}

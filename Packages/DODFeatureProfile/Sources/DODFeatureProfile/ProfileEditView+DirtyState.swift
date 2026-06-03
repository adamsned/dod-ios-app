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
    var toolbarContent: some ToolbarContent {
        #if os(iOS)
        ToolbarItem(placement: .topBarLeading) {
            backChevronButton
        }
        #else
        ToolbarItem(placement: .cancellationAction) {
            backChevronButton
        }
        #endif
        ToolbarItem(placement: .confirmationAction) {
            saveButton
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
        .disabled(!isFormValid || isSubmitting)
        .accessibilityIdentifier("profile-edit-save")
    }
}

import SwiftUI

// T-745 / CL-142 — `handleSave` extracted from ``ProfileEditView``'s
// main file so the file as a whole stays under SwiftLint's
// `file_length` cap after the T-745 additions (two-file storage +
// post-save cleanup for both cropped + original).
//
// What lives here:
// - ``ProfileEditView/handleSave()`` — validates display name +
//   email, builds the persisted ``UserProfile`` (carrying both
//   `photoFilename` + `photoOriginalFilename`), calls
//   ``ProfileStoring/save(_:)``, runs the two-file post-save
//   cleanup (clearing both stale cropped + stale original photo
//   files via the optional ``ProfilePhotoStoring``), then
//   dismisses.
//
// Spec trace: US-44 AC-44.2, AC-44.3, AC-44.8, AC-44.9, AC-44.17;
// CL-136, CL-137, CL-142.

extension ProfileEditView {

    /// Persists the validated profile + runs the two-file post-save
    /// cleanup. Re-entrant guarded via `isSubmitting`. Errors surface
    /// via the form's `saveError` / `emailValidationError` footer
    /// instead of throwing — the parent `SettingsViewModel` never
    /// sees a partial-save failure.
    @MainActor
    func handleSave() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        emailValidationError = nil
        saveError = nil

        do {
            let cleanedName = try UserProfile.validateDisplayName(displayName)
            let cleanedEmail = try UserProfile.validateEmail(email)
            #if canImport(UIKit)
            let originalFilenameToPersist = inFlightPhotoOriginalFilename
            #else
            let originalFilenameToPersist: String? = nil
            #endif
            let profile = UserProfile(
                id: existingProfile?.id ?? UUID(),
                displayName: cleanedName,
                email: cleanedEmail,
                photoFilename: inFlightPhotoFilename,
                photoOriginalFilename: originalFilenameToPersist
            )
            try await store.save(profile)
            #if canImport(UIKit)
            // Phase b — clear the previous cropped photo file only
            // after the Keychain row has been updated with the new
            // filename (write-then-clear-old per CL-137 (h)) so a
            // mid-flow save failure leaves the previous photo intact.
            if let staleFilename = photoFilenameToClearOnSave {
                try? await photoStore?.clear(filename: staleFilename)
                photoFilenameToClearOnSave = nil
            }
            // T-745 / CL-142 — mirror the same write-then-clear-old
            // pattern for the original picked image.
            if let staleOriginalFilename = photoOriginalFilenameToClearOnSave {
                try? await photoStore?.clearOriginal(filename: staleOriginalFilename)
                photoOriginalFilenameToClearOnSave = nil
            }
            #endif
            await onProfileChanged()
            finishAfterSave(cleanedName: cleanedName, cleanedEmail: cleanedEmail)
        } catch let error as UserProfile.ValidationError {
            switch error {
            case .displayNameEmpty:
                saveError = "Add your name to save your profile."
            case .displayNameTooLong:
                // DUT-647 — the shared 1–40 cap; keep it symmetric with the
                // guest/comment path's `GuestIdentitySheet.isValidName`.
                saveError = "Your name is too long (\(UserProfile.maxDisplayNameLength) characters max)."
            case .emailEmpty:
                emailValidationError = "Add your email to save your profile."
            case .emailInvalid:
                emailValidationError = "Enter a valid email address."
            }
            // DUT-410 — the inline error lands far from the focused field, so
            // announce it to VoiceOver too (SwiftUI's AccessibilityNotification,
            // not UIAccessibility — the macOS test slice must compile).
            if let emailValidationError {
                AccessibilityNotification.Announcement(emailValidationError).post()
            }
        } catch {
            saveError = "Couldn't Save Your Profile. Try Again."
        }
    }

    /// DUT-416 — post-save success path. Editing an existing profile returns to
    /// read-only view mode (stays on the page so the user sees their saved
    /// profile + stats), re-baselining the dirty snapshots + reflecting the
    /// cleaned values; the new-profile setup flow dismisses as before.
    @MainActor
    func finishAfterSave(cleanedName: String, cleanedEmail: String) {
        guard existingProfile != nil else {
            dismiss()
            return
        }
        displayName = cleanedName
        email = cleanedEmail
        initialDisplayName = cleanedName
        initialEmail = cleanedEmail
        initialPhotoFilename = inFlightPhotoFilename
        isEditing = false
    }
}

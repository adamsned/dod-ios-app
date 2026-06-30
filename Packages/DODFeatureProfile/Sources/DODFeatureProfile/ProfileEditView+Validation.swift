import SwiftUI

// DUT-414 / DUT-415 — profile form validation: the Save gate + the live,
// per-field error messages rendered directly below the Display Name / Email
// fields (in `ProfileEditView+AppleSignIn.swift`'s `signInSection`). Split from
// `ProfileEditView.swift` so that file stays under the SwiftLint 400-line cap.
extension ProfileEditView {

    /// `true` when the display name passes moderation (non-blank AND not
    /// vulgar/impersonating — DUT-415) AND the email is a valid address. Drives
    /// the Save button's `.disabled(...)`.
    var isFormValid: Bool {
        guard DisplayNameValidator.validate(displayName) == .ok else { return false }
        return (try? UserProfile.validateEmail(email)) != nil
    }

    /// DUT-414 / DUT-415 — live message shown directly below the Display Name
    /// field, explaining why Save is disabled. `nil` when the name is acceptable.
    var displayNameFieldError: String? {
        switch DisplayNameValidator.validate(displayName) {
        case .empty: return "Display name is required."
        case .inappropriate: return "Please choose a different display name and try again."
        case .ok: return nil
        }
    }

    /// DUT-414 — live message shown directly below the Email field. `nil` when
    /// the email is valid.
    var emailFieldError: String? {
        if email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Email is required."
        }
        return (try? UserProfile.validateEmail(email)) == nil ? "Enter a valid email address." : nil
    }
}

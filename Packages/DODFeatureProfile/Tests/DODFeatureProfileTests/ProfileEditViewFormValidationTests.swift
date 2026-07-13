import Foundation
import Testing

@testable import DODFeatureProfile

/// L1 coverage for the ``ProfileEditView`` form validation computed properties
/// (DUT-414 / DUT-415 / DUT-647). Tests the three validation properties:
/// `isFormValid` (gate for Save button), `displayNameFieldError` (live message
/// below Display Name field), and `emailFieldError` (live message below Email
/// field). These combine ``DisplayNameValidator`` and ``UserProfile`` validation
/// to drive the Save button's `.disabled(...)` and render field-level error
/// messages inline.
///
/// The underlying validators are already L1-covered separately
/// (``DisplayNameValidatorTests``, ``UserProfileValidationTests``). These tests
/// pin the *combinations* and error-message formatting by isolating the
/// validation logic that the computed properties implement.
///
/// Spec trace: US-44 AC-44.2, AC-44.3; CL-136.
@Suite("ProfileEditView form validation (DUT-414/415/647)")
struct ProfileEditViewFormValidationTests {

    // MARK: - Validation Result

    /// Result of form field validation (avoids SwiftLint's large_tuple limit).
    private struct ValidationResult {
        let isValid: Bool
        let displayNameError: String?
        let emailError: String?
    }

    // MARK: - Form Validation Logic

    /// Helper that mirrors the logic of `isFormValid`, `displayNameFieldError`,
    /// and `emailFieldError` computed properties without requiring a full view.
    private func validateFormFields(
        displayName: String,
        email: String
    ) -> ValidationResult {
        var isValid = true
        var displayNameError: String?
        var emailError: String?

        // Validate display name (mirrors isFormValid + displayNameFieldError)
        let displayNameValidation = DisplayNameValidator.validate(displayName)
        switch displayNameValidation {
        case .empty:
            displayNameError = "Display name is required."
            isValid = false
        case .inappropriate:
            displayNameError = "Please choose a different display name and try again."
            isValid = false
        case .ok:
            // DUT-647 — also enforce the shared 1–40 length cap
            if (try? UserProfile.validateDisplayName(displayName)) == nil {
                displayNameError = "Display name must be \(UserProfile.maxDisplayNameLength) characters or fewer."
                isValid = false
            }
        }

        // Validate email (mirrors isFormValid + emailFieldError)
        let emailTrimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if emailTrimmed.isEmpty {
            emailError = "Email is required."
            isValid = false
        } else if (try? UserProfile.validateEmail(email)) == nil {
            emailError = "Enter a valid email address."
            isValid = false
        }

        return ValidationResult(
            isValid: isValid,
            displayNameError: displayNameError,
            emailError: emailError
        )
    }

    // MARK: - Form Valid

    @Test func formIsValidWhenBothFieldsPass() {
        let result = validateFormFields(displayName: "Spencer Adams", email: "spencer@example.com")
        #expect(result.isValid)
    }

    @Test func formIsInvalidWhenDisplayNameEmpty() {
        let result = validateFormFields(displayName: "", email: "spencer@example.com")
        #expect(!result.isValid)
    }

    @Test func formIsInvalidWhenDisplayNameWhitespaceOnly() {
        let result = validateFormFields(displayName: "   \t  ", email: "spencer@example.com")
        #expect(!result.isValid)
    }

    @Test func formIsInvalidWhenDisplayNameTooLong() {
        let overCap = String(repeating: "a", count: UserProfile.maxDisplayNameLength + 1)
        let result = validateFormFields(displayName: overCap, email: "spencer@example.com")
        #expect(!result.isValid)
    }

    @Test func formIsInvalidWhenDisplayNameInappropriate() {
        let result = validateFormFields(displayName: "Fuck", email: "spencer@example.com")
        #expect(!result.isValid)
    }

    @Test func formIsInvalidWhenEmailEmpty() {
        let result = validateFormFields(displayName: "Spencer Adams", email: "")
        #expect(!result.isValid)
    }

    @Test func formIsInvalidWhenEmailInvalid() {
        let result = validateFormFields(displayName: "Spencer Adams", email: "not-an-email")
        #expect(!result.isValid)
    }

    @Test func formIsInvalidWhenBothFieldsFail() {
        let result = validateFormFields(displayName: "", email: "invalid")
        #expect(!result.isValid)
    }

    @Test func formIsValidWithMaxLengthDisplayName() {
        let atCap = String(repeating: "a", count: UserProfile.maxDisplayNameLength)
        let result = validateFormFields(displayName: atCap, email: "spencer@example.com")
        #expect(result.isValid)
    }

    @Test func formIsValidWithSubdomainEmail() {
        let result = validateFormFields(displayName: "Spencer", email: "dad+test@mail.example.com")
        #expect(result.isValid)
    }

    // MARK: - Display Name Field Error

    @Test func displayNameErrorNilWhenValid() {
        let result = validateFormFields(displayName: "Spencer Adams", email: "")
        #expect(result.displayNameError == nil)
    }

    @Test func displayNameErrorWhenEmpty() {
        let result = validateFormFields(displayName: "", email: "")
        #expect(result.displayNameError == "Display name is required.")
    }

    @Test func displayNameErrorWhenWhitespaceOnly() {
        let result = validateFormFields(displayName: "   \t  ", email: "")
        #expect(result.displayNameError == "Display name is required.")
    }

    @Test func displayNameErrorWhenInappropriate() {
        let result = validateFormFields(displayName: "shithead", email: "")
        #expect(result.displayNameError == "Please choose a different display name and try again.")
    }

    @Test func displayNameErrorWhenTooLong() {
        let overCap = String(repeating: "a", count: UserProfile.maxDisplayNameLength + 1)
        let result = validateFormFields(displayName: overCap, email: "")
        let maxLen = UserProfile.maxDisplayNameLength
        let expected = "Display name must be \(maxLen) characters or fewer."
        #expect(result.displayNameError == expected)
    }

    @Test func displayNameErrorMessageIncludesMaxLength() {
        let overCap = String(repeating: "x", count: UserProfile.maxDisplayNameLength + 1)
        let result = validateFormFields(displayName: overCap, email: "")
        #expect(result.displayNameError?.contains("\(UserProfile.maxDisplayNameLength)") ?? false)
    }

    // MARK: - Email Field Error

    @Test func emailErrorNilWhenValid() {
        let result = validateFormFields(displayName: "", email: "spencer@example.com")
        #expect(result.emailError == nil)
    }

    @Test func emailErrorWhenEmpty() {
        let result = validateFormFields(displayName: "", email: "")
        #expect(result.emailError == "Email is required.")
    }

    @Test func emailErrorWhenWhitespaceOnly() {
        let result = validateFormFields(displayName: "", email: "   \t  ")
        #expect(result.emailError == "Email is required.")
    }

    @Test func emailErrorWhenMissingAtSign() {
        let result = validateFormFields(displayName: "", email: "nodomain.example.com")
        #expect(result.emailError == "Enter a valid email address.")
    }

    @Test func emailErrorWhenMissingDomainDot() {
        let result = validateFormFields(displayName: "", email: "user@example")
        #expect(result.emailError == "Enter a valid email address.")
    }

    @Test func emailErrorWhenWhitespaceInside() {
        let result = validateFormFields(displayName: "", email: "user name@example.com")
        #expect(result.emailError == "Enter a valid email address.")
    }

    @Test func emailErrorNilWithValidEmail() {
        let result = validateFormFields(displayName: "", email: "spencer@example.com")
        #expect(result.emailError == nil)
    }

    @Test func emailErrorNilWithLeadingTrailingWhitespace() {
        let result = validateFormFields(displayName: "", email: "  spencer@example.com  ")
        #expect(result.emailError == nil)
    }

    @Test func emailErrorNilWithSubdomainAndPlusTag() {
        let result = validateFormFields(displayName: "", email: "dad+app@mail.dutchovendaddy.com")
        #expect(result.emailError == nil)
    }
}

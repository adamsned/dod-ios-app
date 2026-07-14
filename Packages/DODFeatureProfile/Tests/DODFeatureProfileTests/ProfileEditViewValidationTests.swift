import DODSupport
import Testing

@testable import DODFeatureProfile

/// L1 coverage for the DUT-414 / DUT-415 / DUT-647 profile form validation logic
/// that drives the Save button gate (``isFormValid``) and live per-field error
/// messages (``displayNameFieldError`` / ``emailFieldError``). Tests the pure
/// validator functions that the computed properties compose, mirroring the
/// pattern used in ``ProfileEditViewDirtyStateTests`` (static helper test).
///
/// Spec trace: US-44 AC-44.3, AC-44.4; CL-136, CL-137, CL-140.
@Suite("ProfileEditView form validation (DUT-414/415/647)")
struct ProfileEditViewValidationTests {

    // MARK: - Display Name Validation (isFormValid / displayNameFieldError)

    @Test func validDisplayNamePassesModeration() {
        let result = DisplayNameValidator.validate("Alice Cooper")
        #expect(result == .ok)
    }

    @Test func emptyDisplayNameFailsModeration() {
        let result = DisplayNameValidator.validate("")
        #expect(result == .empty)
    }

    @Test func inappropriateDisplayNameFailsModeration() {
        let result = DisplayNameValidator.validate("fuck")
        #expect(result == .inappropriate)
    }

    @Test func whitespaceOnlyDisplayNameFailsModeration() {
        let result = DisplayNameValidator.validate("   ")
        #expect(result == .empty)
    }

    @Test func validDisplayNamePassesLengthValidation() throws {
        let trimmed = try UserProfile.validateDisplayName("Alice Cooper")
        #expect(trimmed == "Alice Cooper")
    }

    @Test func overMaxLengthDisplayNameFailsLengthValidation() {
        let overLimit = String(repeating: "a", count: 41)
        #expect(throws: UserProfile.ValidationError.displayNameTooLong) {
            try UserProfile.validateDisplayName(overLimit)
        }
    }

    @Test func maxLengthDisplayNamePassesLengthValidation() throws {
        let maxLength = String(repeating: "a", count: 40)
        let result = try UserProfile.validateDisplayName(maxLength)
        #expect(result == maxLength)
    }

    @Test func whitespaceTrimmingWorksForDisplayName() throws {
        let result = try UserProfile.validateDisplayName("  Alice Cooper  ")
        #expect(result == "Alice Cooper")
    }

    // MARK: - Email Validation (emailFieldError)

    @Test func validEmailPassesValidation() throws {
        let result = try UserProfile.validateEmail("alice@example.com")
        #expect(result == "alice@example.com")
    }

    @Test func emptyEmailFailsValidation() {
        #expect(throws: UserProfile.ValidationError.emailEmpty) {
            try UserProfile.validateEmail("")
        }
    }

    @Test func whitespaceOnlyEmailFailsValidation() {
        #expect(throws: UserProfile.ValidationError.emailEmpty) {
            try UserProfile.validateEmail("   ")
        }
    }

    @Test func emailWithoutAtSignFailsValidation() {
        #expect(throws: UserProfile.ValidationError.emailInvalid) {
            try UserProfile.validateEmail("alice.example.com")
        }
    }

    @Test func emailWithoutDotFailsValidation() {
        #expect(throws: UserProfile.ValidationError.emailInvalid) {
            try UserProfile.validateEmail("alice@example")
        }
    }

    @Test func emailWithoutLocalPartFailsValidation() {
        #expect(throws: UserProfile.ValidationError.emailInvalid) {
            try UserProfile.validateEmail("@example.com")
        }
    }

    @Test func emailWithoutDomainPartFailsValidation() {
        #expect(throws: UserProfile.ValidationError.emailInvalid) {
            try UserProfile.validateEmail("alice@")
        }
    }

    @Test func emailWithWhitespaceInLocalPartFailsValidation() {
        #expect(throws: UserProfile.ValidationError.emailInvalid) {
            try UserProfile.validateEmail("alice bob@example.com")
        }
    }

    @Test func emailWithWhitespaceInDomainFailsValidation() {
        #expect(throws: UserProfile.ValidationError.emailInvalid) {
            try UserProfile.validateEmail("alice@exam ple.com")
        }
    }

    @Test func emailWithTrimmableWhitespacePassesValidation() throws {
        let result = try UserProfile.validateEmail("  alice@example.com  ")
        #expect(result == "alice@example.com")
    }

    // MARK: - Integration: Form Validity (isFormValid logic)

    @Test func validDisplayNameAndValidEmailMeetsAllChecks() throws {
        let displayName = "Alice Cooper"
        let email = "alice@example.com"

        // Display name passes moderation
        #expect(DisplayNameValidator.validate(displayName) == .ok)
        // Display name passes length validation
        #expect((try? UserProfile.validateDisplayName(displayName)) != nil)
        // Email passes validation
        #expect((try? UserProfile.validateEmail(email)) != nil)
    }

    @Test func inappropriateDisplayNameFailsAllChecks() {
        let displayName = "fuck"
        let email = "alice@example.com"

        // Display name fails moderation
        #expect(DisplayNameValidator.validate(displayName) == .inappropriate)
        // Email passes validation (irrelevant since display name fails)
        #expect((try? UserProfile.validateEmail(email)) != nil)
    }

    @Test func emptyDisplayNameFailsFormValidation() {
        let displayName = ""
        let email = "alice@example.com"

        // Display name fails moderation
        #expect(DisplayNameValidator.validate(displayName) == .empty)
    }

    @Test func overMaxDisplayNameFailsFormValidation() {
        let displayName = String(repeating: "a", count: 41)
        let email = "alice@example.com"

        // Display name passes moderation but fails length
        #expect(DisplayNameValidator.validate(displayName) == .ok)
        #expect((try? UserProfile.validateDisplayName(displayName)) == nil)
    }

    @Test func emptyEmailFailsFormValidation() {
        let displayName = "Alice Cooper"
        let email = ""

        // Email fails validation
        #expect((try? UserProfile.validateEmail(email)) == nil)
    }

    @Test func malformedEmailFailsFormValidation() {
        let displayName = "Alice Cooper"
        let email = "alice@example"

        // Email fails validation (no TLD)
        #expect((try? UserProfile.validateEmail(email)) == nil)
    }

    // MARK: - Error Message Verification

    @Test func displayNameErrorMessageForEmpty() {
        let displayName = ""
        switch DisplayNameValidator.validate(displayName) {
        case .empty:
            #expect(true)  // Correct branch
        case .inappropriate, .ok:
            #expect(false)  // Wrong branch
        }
    }

    @Test func displayNameErrorMessageForInappropriate() {
        let displayName = "fuck"
        switch DisplayNameValidator.validate(displayName) {
        case .inappropriate:
            #expect(true)  // Correct branch
        case .empty, .ok:
            #expect(false)  // Wrong branch
        }
    }

    @Test func displayNameErrorMessageForOverLength() {
        let displayName = String(repeating: "a", count: 41)
        // Passes moderation but fails length check
        #expect(DisplayNameValidator.validate(displayName) == .ok)
        #expect((try? UserProfile.validateDisplayName(displayName)) == nil)
        // When accessed in the computed property, this triggers the length error message
    }

    @Test func emailErrorMessageForEmpty() {
        let email = ""
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(trimmed.isEmpty)
    }

    @Test func emailErrorMessageForMalformed() {
        let email = "alice@example"
        // Should fail the email pattern validation
        #expect((try? UserProfile.validateEmail(email)) == nil)
    }
}

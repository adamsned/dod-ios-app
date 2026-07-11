import DODSupport
import Foundation
import Testing

@testable import DODFeatureProfile

/// L1 for ``SidebarProfileDisplay`` (DUT-940, follow-up to DUT-936) — locks
/// the iPad sidebar profile row's title/subtitle across name/email
/// resolution that prefers `profile` and falls back to `session`
/// field-by-field, plus the signed-in-no-name-or-email and true-guest
/// fallbacks. Apple only returns `displayName`/`email` on the credential
/// from the very first authorization for an Apple ID — every re-auth
/// session can have either field (or both) `nil`.
@Suite struct SidebarProfileDisplayTests {

    @Test func profileWithNameAndEmailShowsTheNameAndEmail() {
        let profile = UserProfile(id: UUID(), displayName: "John Doe", email: "john.doe@a.com")

        let result = SidebarProfileDisplay.resolve(profile: profile, session: nil)

        #expect(result.title == "John Doe")
        #expect(result.subtitle == "john.doe@a.com")
    }

    @Test func sessionWithNameAndEmailShowsTheNameAndEmailWithNoProfile() {
        let session = AppleAuthSession(userIdentifier: "abc123", displayName: "Jane Smith", email: "jane.smith@a.com")

        let result = SidebarProfileDisplay.resolve(profile: nil, session: session)

        #expect(result.title == "Jane Smith")
        #expect(result.subtitle == "jane.smith@a.com")
    }

    @Test func sessionWithEmailOnlyShowsTheEmailAndAddYourNamePrompt() {
        let session = AppleAuthSession(userIdentifier: "abc123", email: "alice@a.com")

        let result = SidebarProfileDisplay.resolve(profile: nil, session: session)

        #expect(result.title == "alice@a.com")
        #expect(result.subtitle == "Add your name")
    }

    @Test func sessionWithNameOnlyShowsTheNameAndAddYourEmailPrompt() {
        let session = AppleAuthSession(userIdentifier: "abc123", displayName: "Bob")

        let result = SidebarProfileDisplay.resolve(profile: nil, session: session)

        #expect(result.title == "Bob")
        #expect(result.subtitle == "Add your email")
    }

    @Test func signedInWithNeitherNameNorEmailShowsSignedInCopy() {
        let session = AppleAuthSession(userIdentifier: "abc123")

        let result = SidebarProfileDisplay.resolve(profile: nil, session: session)

        #expect(result.title == "Signed In")
        #expect(result.subtitle == "Add your name and photo")
    }

    @Test func guestWithNoSessionAndNoProfileShowsSetUpYourProfile() {
        let result = SidebarProfileDisplay.resolve(profile: nil, session: nil)

        #expect(result.title == "Set Up Your Profile")
        #expect(result.subtitle == "Add Your Name and Photo")
    }

    @Test func blankProfileDisplayNameFallsThroughToTheSessionsNameAndEmail() {
        let profile = UserProfile(id: UUID(), displayName: "   ", email: "")
        let session = AppleAuthSession(
            userIdentifier: "abc123",
            displayName: "Charlie Brown",
            email: "charlie.brown@a.com"
        )

        let result = SidebarProfileDisplay.resolve(profile: profile, session: session)

        #expect(result.title == "Charlie Brown")
        #expect(result.subtitle == "charlie.brown@a.com")
    }

    @Test func profileNameAndEmailWinOverAnExistingSessionsNameAndEmail() {
        let profile = UserProfile(id: UUID(), displayName: "David", email: "david@a.com")
        let session = AppleAuthSession(userIdentifier: "abc123", displayName: "Eve", email: "eve@a.com")

        let result = SidebarProfileDisplay.resolve(profile: profile, session: session)

        #expect(result.title == "David")
        #expect(result.subtitle == "david@a.com")
    }

    @Test func blankProfileNameAndBlankEmailWithNoSessionFallsThroughToGuestCopy() {
        let profile = UserProfile(id: UUID(), displayName: "   ", email: "")

        let result = SidebarProfileDisplay.resolve(profile: profile, session: nil)

        #expect(result.title == "Set Up Your Profile")
        #expect(result.subtitle == "Add Your Name and Photo")
    }

    @Test func blankProfileDisplayNameWithANonBlankProfileEmailShowsTheEmailPrompt() {
        let profile = UserProfile(id: UUID(), displayName: "   ", email: "a@b.com")

        let result = SidebarProfileDisplay.resolve(profile: profile, session: nil)

        #expect(result.title == "a@b.com")
        #expect(result.subtitle == "Add your name")
    }

    @Test func namedProfileWithABlankEmailAndNoSessionShowsViewProfileFallback() {
        let profile = UserProfile(id: UUID(), displayName: "John", email: "")

        let result = SidebarProfileDisplay.resolve(profile: profile, session: nil)

        #expect(result.title == "John")
        #expect(result.subtitle == "View profile")
    }
}

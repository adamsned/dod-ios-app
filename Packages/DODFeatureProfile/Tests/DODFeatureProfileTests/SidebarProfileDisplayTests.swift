import DODSupport
import Foundation
import Testing

@testable import DODFeatureProfile

/// L1 for ``SidebarProfileDisplay`` (DUT-935) — locks the iPad sidebar
/// profile row's title/subtitle across the three states: named profile,
/// signed-in-but-no-name-yet (Apple only returns the name on the very first
/// authorization — every re-auth session has a `nil` displayName/email), and
/// true guest (no session, no profile).
@Suite struct SidebarProfileDisplayTests {

    @Test func namedProfileWithNoSessionShowsTheNameAndViewProfile() {
        let profile = UserProfile(id: UUID(), displayName: "John Doe", email: "john.doe@a.com")

        let result = SidebarProfileDisplay.resolve(profile: profile, session: nil)

        #expect(result.title == "John Doe")
        #expect(result.subtitle == "View profile")
    }

    @Test func signedInWithNoProfileShowsSignedInNotSetUpYourProfile() {
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

    @Test func emptyDisplayNameWithNoSessionFallsThroughToGuestCopy() {
        let profile = UserProfile(id: UUID(), displayName: "", email: "a@b.com")

        let result = SidebarProfileDisplay.resolve(profile: profile, session: nil)

        #expect(result.title == "Set Up Your Profile")
        #expect(result.subtitle == "Add Your Name and Photo")
    }

    @Test func emptyDisplayNameWithASessionFallsThroughToSignedInCopy() {
        let profile = UserProfile(id: UUID(), displayName: "", email: "a@b.com")
        let session = AppleAuthSession(userIdentifier: "abc123")

        let result = SidebarProfileDisplay.resolve(profile: profile, session: session)

        #expect(result.title == "Signed In")
        #expect(result.subtitle == "Add your name and photo")
    }

    @Test func whitespaceOnlyDisplayNameIsTreatedAsEmpty() {
        let profile = UserProfile(id: UUID(), displayName: "   ", email: "a@b.com")

        let result = SidebarProfileDisplay.resolve(profile: profile, session: nil)

        #expect(result.title == "Set Up Your Profile")
        #expect(result.subtitle == "Add Your Name and Photo")
    }

    @Test func sessionWithNilEmailStillCountsAsSignedIn() {
        let session = AppleAuthSession(userIdentifier: "abc123", email: nil)

        let result = SidebarProfileDisplay.resolve(profile: nil, session: session)

        #expect(result.title == "Signed In")
        #expect(result.subtitle == "Add your name and photo")
    }

    @Test func namedProfileWinsOverAnExistingSession() {
        let profile = UserProfile(id: UUID(), displayName: "Jane Doe", email: "jane.doe@a.com")
        let session = AppleAuthSession(userIdentifier: "abc123")

        let result = SidebarProfileDisplay.resolve(profile: profile, session: session)

        #expect(result.title == "Jane Doe")
        #expect(result.subtitle == "View profile")
    }
}

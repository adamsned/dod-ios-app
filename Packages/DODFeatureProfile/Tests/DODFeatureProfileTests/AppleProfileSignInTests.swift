import DODSupport
import Foundation
import Testing

@testable import DODFeatureProfile

/// L1 for ``AppleProfileSignIn`` (DUT-189) — the profile-surface Sign in with
/// Apple handler that both persists the ``AppleAuthSession`` AND writes the local
/// ``UserProfile``. Since DUT-238 this is the app's single sign-in path (the
/// separate Settings ▸ Account handler was removed). In-memory stores, `nil`
/// revoker (no network).
struct AppleProfileSignInTests {

    @Test func firstSignIn_writesSessionAndProfile() async {
        let sessionStore = InMemoryAppleAuthSessionStore()
        let profileStore = InMemoryProfileStore()
        let signIn = AppleProfileSignIn(
            profileStore: profileStore,
            sessionStore: sessionStore,
            revoker: nil
        )

        let outcome = await signIn.apply(
            userIdentifier: "u1",
            displayName: "Ned Adams",
            email: "ned@example.com",
            authorizationCode: nil
        )

        // The session is persisted (the user is signed in).
        let session = try? sessionStore.load()
        #expect(session?.userIdentifier == "u1")
        #expect(session?.displayName == "Ned Adams")
        #expect(session?.email == "ned@example.com")

        // The local profile is filled from the credential — the new half.
        let profile = await profileStore.load()
        #expect(profile?.displayName == "Ned Adams")
        #expect(profile?.email == "ned@example.com")

        // The outcome tells the host a valid profile was written → it can dismiss.
        #expect(outcome.profileSaved == true)
        #expect(outcome.displayName == "Ned Adams")
        #expect(outcome.email == "ned@example.com")
    }

    @Test func withheldFields_persistSessionButNotProfile() async {
        let sessionStore = InMemoryAppleAuthSessionStore()
        let profileStore = InMemoryProfileStore()
        let signIn = AppleProfileSignIn(
            profileStore: profileStore,
            sessionStore: sessionStore,
            revoker: nil
        )

        // Apple withholds name + email (declined, or a re-auth with nothing on
        // file). The button still signs them in.
        let outcome = await signIn.apply(
            userIdentifier: "u2",
            displayName: nil,
            email: nil,
            authorizationCode: nil
        )

        #expect((try? sessionStore.load())?.userIdentifier == "u2")
        // No valid profile could be written, so the host keeps the editor open
        // for manual completion.
        let profile = await profileStore.load()
        #expect(profile == nil)
        #expect(outcome.profileSaved == false)
    }

    @Test func reSignIn_carriesFirstAuthNameForwardIntoProfile() async {
        // The first authorization seeded the session's name/email; a later
        // credential omits them (Apple only releases them once). The resolver
        // carries them forward for the same user, so the profile still fills.
        let sessionStore = InMemoryAppleAuthSessionStore(
            initial: AppleAuthSession(
                userIdentifier: "u3",
                displayName: "Chef Ned",
                email: "chef@dod.com"
            )
        )
        let profileStore = InMemoryProfileStore()
        let signIn = AppleProfileSignIn(
            profileStore: profileStore,
            sessionStore: sessionStore,
            revoker: nil
        )

        let outcome = await signIn.apply(
            userIdentifier: "u3",
            displayName: nil,
            email: nil,
            authorizationCode: nil
        )

        let profile = await profileStore.load()
        #expect(profile?.displayName == "Chef Ned")
        #expect(profile?.email == "chef@dod.com")
        #expect(outcome.profileSaved == true)
    }

    @Test func signIn_preservesExistingProfileIdAndPhoto() async {
        // A returning user already has a profile (id + photo). Signing in must
        // merge the credential's name/email WITHOUT minting a new id or dropping
        // the photo (so saved-content attribution + the avatar survive).
        let existingID = UUID()
        let profileStore = InMemoryProfileStore(
            initial: UserProfile(
                id: existingID,
                displayName: "Old Name",
                email: "old@dod.com",
                photoFilename: "avatar.jpg"
            )
        )
        let sessionStore = InMemoryAppleAuthSessionStore()
        let signIn = AppleProfileSignIn(
            profileStore: profileStore,
            sessionStore: sessionStore,
            revoker: nil
        )

        _ = await signIn.apply(
            userIdentifier: "u4",
            displayName: "New Name",
            email: "new@dod.com",
            authorizationCode: nil
        )

        let profile = await profileStore.load()
        #expect(profile?.id == existingID)
        #expect(profile?.displayName == "New Name")
        #expect(profile?.email == "new@dod.com")
        #expect(profile?.photoFilename == "avatar.jpg")
    }
}

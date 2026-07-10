import Foundation
import Testing

@testable import DODFeatureProfile

/// L1 coverage for the DUT Gravatar nudge in the profile photo header. The
/// nudge tells the user their locally-cropped app photo shows only inside the
/// app, and that setting a Gravatar for their email is how the same photo
/// appears on the website + everywhere they comment. This suite pins the link
/// target so a typo can't silently ship a dead / wrong-host link — the copy
/// itself is exercised by the build + snapshot harness.
///
/// Spec trace: DUT — informational nudge only (no comment/avatar logic touched).
@Suite("ProfileEditView Gravatar nudge (DUT)")
struct ProfileEditViewGravatarNudgeTests {

    @Test func gravatarLinkStringIsAValidHTTPSGravatarURL() throws {
        let raw = ProfileEditView.gravatarURLString
        let url = try #require(URL(string: raw))

        #expect(url.scheme == "https")
        #expect(url.host == "gravatar.com")
    }
}

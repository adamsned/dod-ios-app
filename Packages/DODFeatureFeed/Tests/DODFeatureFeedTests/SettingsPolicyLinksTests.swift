import Foundation
import Testing

@testable import DODFeatureFeed

/// L1 coverage for the in-app policy / support link URLs surfaced in Settings.
///
/// DUT-502 (App Store Guideline 5.1.1(i) + 1.2) — the Privacy Policy, Terms of
/// Use, and Contact / Support rows each build a `URL` from these `String`
/// constants with `if let` (force_unwrapping is a hard error in this repo), so a
/// malformed literal would silently drop the row and re-open the App Review
/// blocker. Pinning the literals + asserting each parses into a valid https URL
/// on the owned domain guards against an accidental edit doing that unnoticed.
@Suite("Settings policy links (DUT-502)") struct SettingsPolicyLinksTests {

    @Test func privacyPolicyURLIsAValidHTTPSLinkOnTheOwnedDomain() throws {
        #expect(
            SettingsViewModel.privacyPolicyURLString
                == "https://dutchovendaddy.com/privacy-policy/"
        )
        let url = try #require(URL(string: SettingsViewModel.privacyPolicyURLString))
        #expect(url.scheme == "https")
        #expect(url.host() == "dutchovendaddy.com")
    }

    @Test func termsOfUseURLIsAValidHTTPSLinkOnTheOwnedDomain() throws {
        #expect(
            SettingsViewModel.termsOfUseURLString
                == "https://dutchovendaddy.com/terms/"
        )
        let url = try #require(URL(string: SettingsViewModel.termsOfUseURLString))
        #expect(url.scheme == "https")
        #expect(url.host() == "dutchovendaddy.com")
    }

    @Test func contactSupportURLIsAValidHTTPSLinkOnTheOwnedDomain() throws {
        #expect(
            SettingsViewModel.contactSupportURLString
                == "https://dutchovendaddy.com/contact/"
        )
        let url = try #require(URL(string: SettingsViewModel.contactSupportURLString))
        #expect(url.scheme == "https")
        #expect(url.host() == "dutchovendaddy.com")
    }
}

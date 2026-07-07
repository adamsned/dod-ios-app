import DODDesignSystem
import SwiftUI

// DUT-502 — App Store Guideline 5.1.1(i) / 1.2. The in-app Privacy Policy link
// (DUT-679) is paired here with Terms of Use and a Contact / Support affordance
// so the account + data-collection disclosures App Review expects are all
// reachable inside the app. Extracted into this extension file (like
// `SettingsView+Bindings` / `SettingsView+Feedback`) so `SettingsView.swift`
// stays under the SwiftLint 400-line `file_length` cap.
//
// Each row is a SwiftUI `Link` that routes through the app's tree-wide `openURL`
// override; a non-recipe host falls through to the system browser. URLs are
// built with `if let` from the view-model's `String` constants (force_unwrapping
// is a hard error in this repo), so an unparsable literal drops the row rather
// than crashing.
extension SettingsView {

    /// Privacy Policy + Terms of Use rows for the "Data & Privacy" section.
    @ViewBuilder
    var dataPrivacyPolicyLinks: some View {
        policyLink(
            title: "Privacy Policy",
            urlString: SettingsViewModel.privacyPolicyURLString,
            identifier: "settings-privacy-policy-link"
        )
        policyLink(
            title: "Terms of Use",
            urlString: SettingsViewModel.termsOfUseURLString,
            identifier: "settings-terms-of-use-link"
        )
    }

    /// Contact / Support row for the "About" section.
    @ViewBuilder
    var contactSupportLink: some View {
        policyLink(
            title: "Contact Support",
            urlString: SettingsViewModel.contactSupportURLString,
            identifier: "settings-contact-support-link"
        )
    }

    /// A single external-policy `Link` row: accent-tinted body text, a VoiceOver
    /// label noting it opens in the browser, and a stable a11y identifier for the
    /// UI-test/App-Review surfaces. Renders nothing if the literal won't parse.
    @ViewBuilder
    private func policyLink(
        title: String,
        urlString: String,
        identifier: String
    ) -> some View {
        if let url = URL(string: urlString) {
            Link(destination: url) {
                Text(title)
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.accent)
            }
            .accessibilityIdentifier(identifier)
            .accessibilityLabel("\(title), opens in browser")
        }
    }
}

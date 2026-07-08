import Foundation

// DUT-679 — the Settings → Data & Privacy "Privacy Policy" destination URL.
//
// Split out of `SettingsViewModel.swift` into its own extension file (like
// `SettingsViewModel+Shop.swift`) so the host view + view-model files stay
// under SwiftLint's 400-line `file_length` cap. A `static let` is allowed in an
// extension (unlike an instance stored property), so the constant lives here.

extension SettingsViewModel {

    /// The public Privacy Policy page the Settings → Data & Privacy row opens.
    ///
    /// App Store Review Guideline 5.1.1(i) requires an in-app link to the app's
    /// privacy policy; the Data & Privacy section surfaces it via a SwiftUI
    /// `Link` that routes through the app's tree-wide `openURL` override (a
    /// non-recipe host falls through to the system browser).
    ///
    /// Stored as a `String` (not a force-unwrapped `URL`) so it stays
    /// SwiftLint-clean (`force_unwrapping` is an error in this repo) and the L1
    /// suite can pin the literal; the row builds the `URL` with `if let`.
    public nonisolated static let privacyPolicyURLString =
        "https://dutchovendaddy.com/privacy-policy/"

    /// The public Terms of Use page the Settings → Data & Privacy row opens.
    ///
    /// DUT-502 — pairs with the Privacy Policy link so the account/data-collection
    /// disclosures App Review expects (Guideline 5.1.1) are both reachable in-app.
    /// Same `String`-not-`URL` convention as `privacyPolicyURLString` above.
    public nonisolated static let termsOfUseURLString =
        "https://dutchovendaddy.com/terms/"

    /// The public Contact / Support page the Settings → About row opens.
    ///
    /// DUT-502 — a reachable, published contact affordance in-app helps satisfy
    /// App Review Guideline 1.2 (published developer contact) alongside the
    /// privacy/terms disclosures.
    public nonisolated static let contactSupportURLString =
        "https://dutchovendaddy.com/contact/"
}

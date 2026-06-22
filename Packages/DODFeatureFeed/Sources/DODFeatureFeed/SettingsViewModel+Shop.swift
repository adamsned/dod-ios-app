import Foundation

// US-45 / AC-45.3 (T-790, DUT-94) — the Settings → Shop destination URL.
//
// Split out of `SettingsViewModel.swift` into its own extension file (like
// `SettingsViewModel+CloudSync.swift` / `SettingsViewModel+Voice.swift`) so the
// host file stays under SwiftLint's 400-line `file_length` cap. A `static let`
// is allowed in an extension (unlike an instance stored property), so the
// constant lives cleanly here.

extension SettingsViewModel {

    /// The BuzzyWaxx storefront the Settings → Shop "Buy" row opens in the
    /// system browser. Points at the owned Shopify "Shop All" collection
    /// (on-site checkout) — the direct store, not Amazon, so DOD keeps full
    /// margin + first-party customer data (BuzzyWaxx is a sister brand under
    /// common ownership).
    ///
    /// BuzzyWaxx seasoning wax is a PHYSICAL good consumed outside the app, so
    /// App Store Review Guideline 3.1.3(e) governs: an external link to a web
    /// checkout is the compliant path — **no StoreKit / IAP** for this surface.
    /// Stored as a `String` (not a force-unwrapped `URL`) so it stays
    /// SwiftLint-clean (`force_unwrapping` is an error in this repo) and the L1
    /// suite can pin the literal; the Feed's Cooking Tools menu builds the `URL`
    /// at the call site with `if let` (DUT-196 moved the Buy BuzzyWaxx entry off
    /// the former Settings ▸ Shop section into the Feed menu).
    ///
    /// Spec trace: US-45 / AC-45.1..AC-45.3 (DUT-94 / CL-186).
    public nonisolated static let buyBuzzyWaxxURLString =
        "https://buzzywaxx.com/collections/frontpage"
}

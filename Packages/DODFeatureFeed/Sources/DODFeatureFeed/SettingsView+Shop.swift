import DODDesignSystem
import SwiftUI

// US-45 / AC-45.1..AC-45.5 (T-790, DUT-94) — the Settings → Shop section:
// a single "Buy BuzzyWaxx Seasoning" row that links out to the owned
// BuzzyWaxx storefront in the system browser.
//
// Extracted from `SettingsView.swift` (like `SettingsView+CloudSync.swift`
// and `SettingsView+Voice.swift`) so the host file stays under SwiftLint's
// 400-line `file_length` cap. `ShopSection` owns its full `Section` (header +
// row + footer) so the host's edit is a single insertion line.
//
// Why an external link and not in-app commerce (CL-186): BuzzyWaxx seasoning
// wax is a PHYSICAL good consumed outside the app, so App Store Review
// Guideline 3.1.3(e) makes a web checkout the compliant path — there is NO
// StoreKit / IAP here, and no native cart / catalog / checkout. The system
// browser (not an in-app `WKWebView`) is the strongest "you are leaving the
// app to a real store" reviewer signal. The destination URL lives on
// `SettingsViewModel.buyBuzzyWaxxURLString` (a `String`, not a force-unwrapped
// `URL`, so the repo's `force_unwrapping`-as-error lint stays clean and the L1
// suite can pin the literal).

// MARK: - Shop section

/// Renders the Settings "Shop" `Section`: a single "Buy BuzzyWaxx Seasoning"
/// row that opens the BuzzyWaxx storefront in the system browser.
///
/// Self-contained — it reads the static destination URL off
/// ``SettingsViewModel`` and drives the hand-off through the SwiftUI
/// `openURL` environment action (the same action `SettingsView+Voice` uses to
/// deep-link to iOS Settings), so it needs no view-model instance and no
/// network state. v1 is untracked (no analytics event) per CL-186.
struct ShopSection: View {

    /// System `openURL` so the Buy row hands off to the user's default
    /// browser. Uses the environment action rather than
    /// `UIApplication.shared.open` so the type compiles on the macOS
    /// `swift test` slice (UIKit-free) and stays testable. The Settings
    /// screen is outside the Feed's overridden `openURL` scope, so this
    /// reaches the system handler directly.
    @Environment(\.openURL) private var openURL

    var body: some View {
        Section {
            buyRow
        } header: {
            // Custom `Text` header (not the `Section("…")` string form) so the
            // brand font + color apply — matches `SettingsView.sectionHeader`.
            Text("Shop")
                .dodFont(DODType.heading)
                .foregroundStyle(DODColor.label)
        } footer: {
            Text(
                "BuzzyWaxx cast iron seasoning wax ships from the BuzzyWaxx web store. Tapping opens it in your browser."
            )
            .dodFont(DODType.caption)
            .foregroundStyle(DODColor.labelSecondary)
        }
        .listRowBackground(DODColor.surfaceElevated)
    }

    // MARK: Rows

    /// AC-45.2 / AC-45.3 — the "Buy BuzzyWaxx Seasoning" row. A `Button` (so it
    /// carries the `.isButton` trait for VoiceOver) with a leading
    /// `shippingbox.fill` glyph (signals a physical good that ships), the
    /// Title-Case primary label, a secondary line naming the physical product,
    /// and a trailing `arrow.up.forward.app` external-link affordance. Both
    /// glyphs are decorative; the action + "opens in browser" live on the
    /// accessibility label.
    private var buyRow: some View {
        Button {
            openStore()
        } label: {
            HStack(spacing: DODSpacing.sm) {
                Image(systemName: "shippingbox.fill")
                    .foregroundStyle(DODColor.accent)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DODSpacing.xxs) {
                    Text("Buy BuzzyWaxx Seasoning")
                        .dodFont(DODType.body)
                        .foregroundStyle(DODColor.label)
                    Text("Cast iron seasoning wax · ships from buzzywaxx.com")
                        .dodFont(DODType.detail)
                        .foregroundStyle(DODColor.labelSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.up.forward.app")
                    .foregroundStyle(DODColor.accent)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings-button-shop-buzzywaxx")
        .accessibilityLabel("Buy BuzzyWaxx cast iron seasoning, opens in browser")
    }

    // MARK: Actions

    /// Open the BuzzyWaxx storefront in the system browser. The URL is built
    /// at the call site with `if let` from the `String` constant so the repo's
    /// `force_unwrapping`-as-error lint stays satisfied (mirrors how
    /// `SettingsView+Voice.openSettings()` constructs `openSettingsURLString`).
    private func openStore() {
        if let url = URL(string: SettingsViewModel.buyBuzzyWaxxURLString) {
            openURL(url)
        }
    }
}

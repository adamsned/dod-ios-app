import AppIntents
import SwiftUI
import WidgetKit

// DUT-480 / T-907 — an iOS 18 Control Center / Lock Screen / Action-button
// control that opens the app straight to the Shopping List screen
// (empty-first, CL-301). `ControlWidget` is iOS 18+ ONLY, so the whole file is
// `@available(iOS 18.0, *)`-gated; on iOS 17 (the app's deployment target) the
// control simply isn't offered by the system, which is fine.
//
// RUNTIME CHECK REQUIRED — Control Center behavior isn't unit-testable. After a
// build change here, add the control in Settings ▸ Control Center (or the
// Control Center gallery), tap it, and confirm the app foregrounds straight to
// the Shopping List. Verify on a device / iOS 18 sim.

/// Control Center / Lock Screen control (iOS 18) with a shopping-cart icon +
/// "Shopping List" label. Tapping it opens the app to the `dod://shopping-list`
/// deep link (DUT-480 / CL-301 / T-907).
///
/// The button's action is the system ``OpenURLIntent`` directly.
/// `OpenURLIntent` conforms to `AppIntent`, so `ControlWidgetButton(action:)`
/// accepts it, and the system foregrounds the app + delivers the URL through
/// `RootView.onOpenURL` → `WidgetDeepLinkParser` → the Shopping List — the same
/// path every other `dod://` widget link uses, no bespoke launch handling.
///
/// DUT-480 fix: the earlier custom `OpenShoppingListIntent` combined
/// `openAppWhenRun = true` AND a `perform()` returning `.result(opensIntent:)`.
/// That did nothing when tapped (the control never even opened the app); the
/// two foregrounding mechanisms stacked on top of each other. Handing the URL
/// intent straight to the button is the documented "open a URL" control shape.
@available(iOS 18.0, *)
struct ShoppingListControl: ControlWidget {
    // Matches the `com.dutchovendaddy.DODApp.Widget.` kind prefix the other
    // widgets in this extension use (see FeaturedRecipeWidget etc.).
    static let kind = "com.dutchovendaddy.DODApp.Widget.ShoppingListControl"

    // The deep link the control opens. A static, always-valid literal, so a
    // `URL(string:)` failure is impossible; the `?? .init(string: "dod://")`
    // fallback exists only to avoid a force-unwrap (swiftlint) and never runs.
    private static let shoppingListURL =
        URL(string: "dod://shopping-list") ?? URL(fileURLWithPath: "/")

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenURLIntent(Self.shoppingListURL)) {
                Label("Shopping List", systemImage: "cart")
            }
        }
        .displayName("Shopping List")
        .description("Open your Dutch Oven Daddy shopping list.")
    }
}

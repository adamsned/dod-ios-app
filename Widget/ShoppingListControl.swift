import AppIntents
import DODSupport
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

/// DUT-480 fix — the intent the Shopping List control runs when tapped.
///
/// Handing a `dod://` URL to the control via `OpenURLIntent` did NOT reliably
/// launch the app at runtime (a custom URL scheme handed off from a Control
/// isn't a dependable foregrounding mechanism), so the `onOpenURL` →
/// ``WidgetDeepLinkParser`` path never ran. Instead this custom intent sets
/// `openAppWhenRun = true` — the system foregrounds the app for us — and
/// `perform()` drops a one-shot pending-route flag into the shared App Group
/// via ``ControlRouteStore``. ``RootView`` reads + clears that flag on cold
/// launch and on every `.active` transition and routes to the Shopping List.
@available(iOS 18.0, *)
struct OpenShoppingListIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Shopping List"

    // The system brings the app to the foreground when this intent runs; we
    // don't (and can't reliably) do it ourselves from a Control.
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        // Fire-and-forget: a nil store (unopenable App Group suite) just means
        // the app foregrounds without the flag — no crash, no Shopping List.
        ControlRouteStore()?.setPending(.shoppingList)
        return .result()
    }
}

/// Control Center / Lock Screen control (iOS 18) with a shopping-cart icon +
/// "Shopping List" label. Tapping it runs ``OpenShoppingListIntent`` — the
/// system foregrounds the app and the intent leaves the pending-route flag
/// ``RootView`` consumes to open the Shopping List (DUT-480 / CL-301 / T-907).
@available(iOS 18.0, *)
struct ShoppingListControl: ControlWidget {
    // Matches the `com.dutchovendaddy.DODApp.Widget.` kind prefix the other
    // widgets in this extension use (see FeaturedRecipeWidget etc.).
    static let kind = "com.dutchovendaddy.DODApp.Widget.ShoppingListControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenShoppingListIntent()) {
                Label("Shopping List", systemImage: "cart")
            }
        }
        .displayName("Shopping List")
        .description("Open your Dutch Oven Daddy shopping list.")
    }
}

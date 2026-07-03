import AppIntents
import SwiftUI
import WidgetKit

// DUT-480 / T-907 — an iOS 18 Control Center / Lock Screen / Action-button
// control that opens the app straight to the Shopping List screen
// (empty-first, CL-301). `ControlWidget` is iOS 18+ ONLY, so the whole file is
// `@available(iOS 18.0, *)`-gated; on iOS 17 (the app's deployment target) the
// control simply isn't offered by the system, which is fine.

/// App Intent that opens the app to the `dod://shopping-list` deep link. The
/// app's `RootView.onOpenURL` parses that URL through `WidgetDeepLinkParser`
/// and routes it to the Shopping List screen (DUT-480). `openAppWhenRun`
/// foregrounds the app; `perform()` then hands off to the system
/// `OpenURLIntent` so the URL flows through the same `.onOpenURL` path every
/// other `dod://` widget link uses — no bespoke launch handling.
@available(iOS 18.0, *)
struct OpenShoppingListIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Shopping List"
    static let description = IntentDescription(
        "Opens your Dutch Oven Daddy shopping list."
    )

    /// Foreground the app when the control is tapped.
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        guard let url = URL(string: "dod://shopping-list") else {
            return .result(opensIntent: OpenURLIntent())
        }
        return .result(opensIntent: OpenURLIntent(url))
    }
}

/// Control Center / Lock Screen control (iOS 18) with a shopping-cart icon +
/// "Shopping List" label. Tapping it runs ``OpenShoppingListIntent``, which
/// opens the app to `dod://shopping-list` (DUT-480 / CL-301 / T-907).
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

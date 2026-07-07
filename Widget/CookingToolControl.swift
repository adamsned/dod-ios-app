import AppIntents
import DODSupport
import SwiftUI
import WidgetKit

// DUT-560 / T-913 — a CONFIGURABLE iOS 18 Control Center / Lock Screen /
// Action-button control that opens the app straight to whichever cooking tool
// the user picks (DUT-480 shipped a fixed Shopping List control; DUT-560
// generalizes it). `ControlWidget` is iOS 18+ ONLY, so the whole file is
// `@available(iOS 18.0, *)`-gated; on iOS 17 (the app's deployment target) the
// control simply isn't offered by the system, which is fine.
//
// RUNTIME CHECK REQUIRED — Control Center behavior isn't unit-testable. After a
// build change here, add the control in Settings ▸ Control Center (or the
// Control Center gallery), pick each tool, tap it, and confirm the app
// foregrounds straight to that tool. Verify on a device / iOS 18 sim.

/// DUT-560 — the six cooking tools the configurable control can open. Each case
/// carries a Title-Case display name, an SF Symbol, and a mapping to the
/// ``ControlRouteStore/Route`` the app consumes on next activation.
@available(iOS 18.0, *)
enum CookingToolControlOption: String, AppEnum {
    case shoppingList
    case heatCoach
    case cookingJournal
    case firstCookout
    case cookMode
    case buyBuzzyWaxx

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Cooking Tool")

    static let caseDisplayRepresentations: [CookingToolControlOption: DisplayRepresentation] = [
        .shoppingList: "Shopping List",
        .heatCoach: "Heat Coach",
        .cookingJournal: "Cooking Journal",
        .firstCookout: "Your First Cookout",
        .cookMode: "Cook Mode",
        .buyBuzzyWaxx: "Buy BuzzyWaxx",
    ]

    /// The button's user-facing label (matches the picker's display name).
    var displayLabel: String {
        switch self {
        case .shoppingList: "Shopping List"
        case .heatCoach: "Heat Coach"
        case .cookingJournal: "Cooking Journal"
        case .firstCookout: "Your First Cookout"
        case .cookMode: "Cook Mode"
        case .buyBuzzyWaxx: "Buy BuzzyWaxx"
        }
    }

    /// The SF Symbol shown on the control button.
    var symbol: String {
        switch self {
        case .shoppingList: "cart"
        case .heatCoach: "thermometer.medium"
        case .cookingJournal: "book.closed.fill"
        case .firstCookout: "flame.fill"
        case .cookMode: "flame.circle.fill"
        case .buyBuzzyWaxx: "bag.fill"
        }
    }

    /// The one-shot ``ControlRouteStore/Route`` the app consumes to open this tool.
    var route: ControlRouteStore.Route {
        switch self {
        case .shoppingList: .shoppingList
        case .heatCoach: .heatCoach
        case .cookingJournal: .cookingJournal
        case .firstCookout: .firstCookout
        case .cookMode: .cookMode
        case .buyBuzzyWaxx: .buyBuzzyWaxx
        }
    }
}

/// DUT-560 — the control's configuration intent: the parameter the user edits
/// in the Control Center gallery to choose which tool the control opens.
@available(iOS 18.0, *)
struct SelectCookingToolIntent: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "Select Cooking Tool"

    @Parameter(title: "Cooking Tool", default: .shoppingList)
    var tool: CookingToolControlOption
}

/// DUT-560 (generalizes DUT-480's `OpenShoppingListIntent`) — the intent the
/// control runs when tapped.
///
/// Handing a `dod://` URL to the control via `OpenURLIntent` did NOT reliably
/// launch the app at runtime, so the `onOpenURL` → ``WidgetDeepLinkParser``
/// path never ran. Instead this custom intent sets `openAppWhenRun = true` —
/// the system foregrounds the app for us — and `perform()` drops a one-shot
/// pending-route flag into the shared App Group via ``ControlRouteStore``.
/// ``RootView`` reads + clears that flag on cold launch and on every `.active`
/// transition and routes to the chosen tool.
@available(iOS 18.0, *)
struct OpenCookingToolIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Cooking Tool"

    // The system brings the app to the foreground when this intent runs; we
    // don't (and can't reliably) do it ourselves from a Control.
    static let openAppWhenRun = true

    /// DUT-691 — the chosen tool as the typed ``CookingToolControlOption``
    /// AppEnum WITH a default (was a raw, defaultless `toolToken: String`). A
    /// required untyped String couldn't be resolved in the non-interactive
    /// Control context, so the button's intent silently failed to run (the tap
    /// opened nothing). The typed enum + default mirrors ``SelectCookingToolIntent``
    /// and also gives the Shortcuts action a proper picker instead of a text field.
    @Parameter(title: "Cooking Tool", default: .shoppingList)
    var tool: CookingToolControlOption

    init() {}

    init(tool: CookingToolControlOption) { self.tool = tool }

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$tool)")
    }

    func perform() async throws -> some IntentResult {
        let route = tool.route
        ControlRouteStore()?.setPending(route)
        // DUT-690 — `openAppWhenRun` foregrounds the app; the App Group flag above
        // is how the app learns WHICH tool to open (app + widget both carry the
        // App Group entitlement on signed builds). We deliberately do NOT return
        // an `opensIntent: OpenURLIntent`: a `dod://` custom scheme opens
        // unreliably from a Control AND returning it suppressed the openAppWhenRun
        // foreground, so the tap opened NOTHING (the DUT-674 regression). The
        // dod:// grammar still exists for deep links; the control just skips it.
        DODLog.app.notice("CookingToolControl tapped; pending route = \(route.rawValue, privacy: .public)")
        return .result()
    }
}

/// DUT-560 — the configurable Control Center / Lock Screen control (iOS 18).
/// The user picks a cooking tool via ``SelectCookingToolIntent``; tapping the
/// control runs ``OpenCookingToolIntent`` — the system foregrounds the app and
/// the intent leaves the pending-route flag ``RootView`` consumes to open the
/// chosen tool.
@available(iOS 18.0, *)
struct CookingToolControl: ControlWidget {
    // A NEW kind (DUT-480's `ShoppingListControl` is replaced). Matches the
    // `com.dutchovendaddy.DODApp.Widget.` kind prefix the other widgets use.
    static let kind = "com.dutchovendaddy.DODApp.Widget.CookingToolControl"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: Self.kind,
            provider: Provider()
        ) { tool in
            ControlWidgetButton(action: OpenCookingToolIntent(tool: tool)) {
                Label(tool.displayLabel, systemImage: tool.symbol)
            }
        }
        .displayName("Cooking Tool")
        .description("Open the cooking tool you choose.")
    }

    /// Supplies the currently-configured tool to the control's content closure.
    struct Provider: AppIntentControlValueProvider {
        func previewValue(configuration: SelectCookingToolIntent) -> CookingToolControlOption {
            configuration.tool
        }

        func currentValue(
            configuration: SelectCookingToolIntent
        ) async throws -> CookingToolControlOption {
            configuration.tool
        }
    }
}

import AppIntents
import DODSupport
import Foundation

// DUT-692 — the Cooking Tools control's tool enum + its tap-action intent live
// here, in a source file compiled into BOTH the app (DODApp) AND the widget
// extension (DODAppWidget) targets.
//
// WHY THIS MUST BE SHARED: `OpenCookingToolIntent` sets `openAppWhenRun = true`,
// which tells iOS to open the CONTAINING APP to run the intent — so the intent's
// code has to exist in the APP binary, not only the widget extension. Before
// DUT-692 these types lived only in Widget/CookingToolControl.swift (widget
// target only), so the app had no `OpenCookingToolIntent` to run: tapping the
// Control did nothing (the app opened an intent it didn't contain → silently
// failed) and running the Shortcuts action reported "internal error occurred"
// (perform() never ran — confirmed by the app's AppIntents metadata lacking the
// intent, and by an empty Console). Compiling the intent into the app fixes it.
//
// `CookingToolControl` (the ControlWidget) and `SelectCookingToolIntent` (the
// configuration intent) stay widget-only in Widget/CookingToolControl.swift —
// only these two shared types move here.

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

/// DUT-560 (generalizes DUT-480's `OpenShoppingListIntent`) — the intent the
/// control runs when tapped. Must be compiled into the APP target (see the file
/// header): `openAppWhenRun` runs it in the app process.
///
/// `perform()` drops a one-shot pending-route flag into the shared App Group via
/// ``ControlRouteStore``; ``RootView`` reads + clears it on cold launch and on
/// every `.active` transition and routes to the chosen tool.
@available(iOS 18.0, *)
struct OpenCookingToolIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Cooking Tool"

    // The system brings the app to the foreground (and runs this intent in the
    // app process) when the intent runs.
    static let openAppWhenRun = true

    /// DUT-691 — the chosen tool as the typed ``CookingToolControlOption`` AppEnum
    /// WITH a default (was a raw, defaultless `toolToken: String`). A required
    /// untyped String couldn't be resolved in the non-interactive Control context;
    /// the typed enum + default mirrors ``SelectCookingToolIntent`` and gives the
    /// Shortcuts action a proper picker instead of a text field.
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
        DODLog.app.notice("CookingToolControl tapped; pending route = \(route.rawValue, privacy: .public)")
        return .result()
    }
}

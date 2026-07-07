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

// DUT-692 — `CookingToolControlOption` (the tool enum) and `OpenCookingToolIntent`
// (the tap action) moved to Shared/CookingToolIntents.swift, which is compiled
// into BOTH the app and this widget extension. `openAppWhenRun` runs the action
// intent in the APP process, so the app binary must contain it — a widget-only
// definition made the Control (and the Shortcuts action) fail with nothing / an
// "internal error". Only the config intent + the ControlWidget stay here.

/// DUT-560 — the control's configuration intent: the parameter the user edits
/// in the Control Center gallery to choose which tool the control opens.
@available(iOS 18.0, *)
struct SelectCookingToolIntent: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "Select Cooking Tool"

    @Parameter(title: "Cooking Tool", default: .shoppingList)
    var tool: CookingToolControlOption
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

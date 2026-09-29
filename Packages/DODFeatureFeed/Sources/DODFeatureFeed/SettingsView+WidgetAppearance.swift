import DODDesignSystem
import DODSupport
import SwiftUI

/// v2 "Seasoned Cast Iron" → widgets. The "Applies to Widgets" toggle that pops
/// out under the App Appearance picker while Seasoned Cast Iron is selected, plus
/// the App-Group sync that carries the choice to the widget process.
///
/// When on, the widgets adopt the true-OLED Seasoned Cast Iron background instead
/// of the Cocoa/Flour surface (see `WidgetAppearanceBridge` + the widget-side
/// `.dodWidgetSeasonedCastIron()`). Applies to all users and stays in the public
/// release (unlike the Dev Debug section).
extension SettingsView {

    /// `@AppStorage` key (standard defaults) for the "Applies to Widgets" toggle.
    static let appearanceAppliesToWidgetsKey = "dod.settings.appearanceAppliesToWidgets"

    /// Shown only while Seasoned Cast Iron is the selected appearance. Toggling
    /// it writes the derived flag to the App Group and reloads widget timelines.
    @ViewBuilder
    var appliesToWidgetsToggle: some View {
        if viewModel.appearance == .seasonedCastIron {
            Toggle(isOn: $appearanceAppliesToWidgets) {
                Text("Applies to Widgets")
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.label)
            }
            .tint(DODColor.burntOrange)
            .accessibilityIdentifier("settings-toggle-appearance-widgets")
            .onChange(of: appearanceAppliesToWidgets) { _, on in
                WidgetAppearanceBridge.setWidgetsUseSeasonedCastIron(
                    viewModel.appearance == .seasonedCastIron && on
                )
            }
        }
    }

    /// Recompute + push the widget flag after the appearance itself changes
    /// (e.g. Seasoned Cast Iron → Cocoa must revert the widgets). Called from
    /// `appearanceBinding`.
    func syncWidgetSeasonedCastIron(for appearance: AppearancePreference) {
        WidgetAppearanceBridge.setWidgetsUseSeasonedCastIron(
            appearance == .seasonedCastIron && appearanceAppliesToWidgets
        )
    }
}

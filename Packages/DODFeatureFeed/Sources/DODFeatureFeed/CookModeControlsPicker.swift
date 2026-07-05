import DODDesignSystem
import DODSupport
import SwiftUI

/// DUT-596 — the "Auto Minimize Cook Mode Controls After" picker shown in
/// Settings ▸ Customization. Binds the shared
/// ``CookModeControlsAutoMinimize/preferenceKey`` `@AppStorage` that Cook Mode's
/// player panel reads, so this one control drives how long Cook Mode waits
/// before dimming its transport bar. A standalone `View` (like
/// ``LayoutSettingPicker``) so `SettingsView` stays under the file-length cap.
struct CookModeControlsPicker: View {

    @AppStorage(CookModeControlsAutoMinimize.preferenceKey) private var seconds =
        CookModeControlsAutoMinimize.defaultSeconds

    var body: some View {
        Picker(selection: $seconds) {
            ForEach(CookModeControlsAutoMinimize.options, id: \.self) { value in
                Text(CookModeControlsAutoMinimize.label(for: value))
                    .tag(value)
            }
        } label: {
            // Explicit `\n` so the (long) label stays narrow enough for the value
            // to sit to its right, matching the "Recipe Step Temperatures" row.
            Text("Auto Minimize Cook Mode\nControls After")
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.label)
        }
        // Brand-orange menu value + chevron, matching the pickers above it.
        .tint(DODColor.burntOrange)
        .accessibilityIdentifier("settings-picker-cook-mode-auto-minimize")
    }
}

import DODDesignSystem
import DODSupport
import SwiftUI

/// DUT-173 — Settings ▸ Customization toggle for "auto-advance when a step
/// timer finishes". Binds the same `@AppStorage` key Cook Mode reads.
struct CookModeAutoAdvanceToggle: View {

    @AppStorage(CookModeAutoAdvance.preferenceKey) private var enabled =
        CookModeAutoAdvance.defaultEnabled

    var body: some View {
        Toggle(isOn: $enabled) {
            Text("Auto-Advance When Timer Ends")
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.label)
        }
        .tint(DODColor.burntOrange)
        .accessibilityIdentifier("settings-toggle-cook-mode-auto-advance")
    }
}

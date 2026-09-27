import DODDesignSystem
import SwiftUI

// DUT-160 — the Settings ▸ Data & Privacy entry point that pushes the Privacy
// Dashboard ("Where your data lives"). Kept in its own extension file (like
// `SettingsView+PolicyLinks`) so `SettingsView.swift` stays at/under the
// SwiftLint 400-line `file_length` cap; the row is composed into the Data &
// Privacy section from `dataPrivacyPolicyLinks`.
extension SettingsView {

    /// A `NavigationLink` row that pushes ``PrivacyDashboardView``. Sits in the
    /// Data & Privacy section (above the Privacy Policy / Terms links). Hands the
    /// dashboard the sheet-level `dismiss` so a cross-tab deep link can close
    /// Settings and reveal its destination.
    @ViewBuilder
    var privacyDashboardLink: some View {
        NavigationLink {
            PrivacyDashboardView(settings: viewModel, onCloseSettings: { dismiss() })
        } label: {
            Text("Privacy Dashboard")
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.label)
        }
        .accessibilityIdentifier("settings-link-privacy-dashboard")
    }
}

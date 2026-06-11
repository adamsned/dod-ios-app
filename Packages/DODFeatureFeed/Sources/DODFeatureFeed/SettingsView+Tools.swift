import DODDesignSystem
import SwiftUI

/// The Settings "Tools" section (DUT-48). A single `NavigationLink` row that
/// pushes the ``HeatCoachView`` Dutch Oven Heat Coach.
///
/// Extracted from `SettingsView.swift` so that file stays under the 400-line
/// `file_length` cap — the same split pattern as `SettingsView+Voice.swift`
/// and `SettingsView+CloudSync.swift`.
///
/// **Why a Settings row (not a tab) in v1:** a dedicated "Tools" tab is the
/// eventual home for the Heat Coach, but a Settings entry keeps the DUT-48 PR
/// small and reviewable — no new tab, no new SPM module/target — while the
/// feature proves out. It pushes onto the Settings `NavigationStack` exactly
/// like the existing About row.
struct ToolsSection: View {

    var body: some View {
        Section {
            NavigationLink {
                HeatCoachView()
            } label: {
                Text("Dutch Oven Heat Coach")
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.label)
            }
            .accessibilityIdentifier("settings-link-heat-coach")
        } header: {
            // T-751 / CL-148 (DUT-57) — `heading` + primary `label` so the
            // subheader reads larger + bolder than the footer description
            // (which stays `caption` + `labelSecondary`).
            Text("Tools")
                .dodFont(DODType.heading)
                .foregroundStyle(DODColor.label)
        } footer: {
            Text("A starting point for coals — then cook by feel.")
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
        }
        .listRowBackground(DODColor.surfaceElevated)
    }
}

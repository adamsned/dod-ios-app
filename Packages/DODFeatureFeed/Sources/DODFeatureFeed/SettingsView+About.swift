import DODDesignSystem
import SwiftUI

// The trailing About + Dev-Debug + version-footer sections, split out of
// `SettingsView.swift` so that host file stays under the SwiftLint 400-line
// `file_length` cap (the same partitioning rule the Bindings / Feedback splits
// follow). Behavior is unchanged — this is a mechanical move.
extension SettingsView {

    /// The "About Dutch Oven Daddy" section, the (dev-only) Dev Debug section,
    /// and the version footer, in top-to-bottom order.
    @ViewBuilder
    var aboutAndVersionSections: some View {
        // MARK: US-32 About + version

        Section {
            NavigationLink {
                AboutNedView()
            } label: {
                Text("About Dutch Oven Daddy")
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.label)
            }
            .accessibilityIdentifier("settings-link-about")

            // DUT-502 — a published Contact / Support affordance in-app
            // (Guideline 1.2). See `SettingsView+PolicyLinks.swift`.
            contactSupportLink
        }
        .listRowBackground(DODColor.surfaceElevated)

        devDebugSection  // ⚠️ DEV DEBUG — strip before public release

        Section {
            EmptyView()
        } footer: {
            Text(SettingsViewModel.versionFooter())
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityIdentifier("settings-version-footer")
                .devDebugFooterUnlock(unlocked: $devDebugUnlocked, forceShowOwnerUI: $devForceShowOwnerUI)
        }
        .listRowBackground(DODColor.surfaceElevated)
    }
}

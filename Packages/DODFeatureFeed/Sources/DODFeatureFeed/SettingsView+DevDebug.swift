import DODDesignSystem
import DODSupport
import SwiftUI

// ============================================================================
// ⚠️ DEV DEBUG — STRIP BEFORE ANY PUBLIC RELEASE ⚠️
//
// Developer-only Settings section (Dad + Spencer, internal TestFlight channel).
// The whole feature is isolated so it strips in a few deletions:
//   1. Delete this file and `DevDebug.swift`.
//   2. In `SettingsView.swift`: delete the `devDebugUnlocked` /
//      `devForceShowOwnerUI` / `devDebugIsOwner` properties, the
//      `devDebugSection` call + its `.task { devDebugIsOwner = ... }`, and the
//      version-footer `.onLongPressGesture` unlock.
//   3. Drop the `|| devForceShowOwnerUI` clauses in `FeedView` (compose button)
//      and `SettingsView+Profile` (Daddy's Tools row).
// Claude will refuse to help ship a public build while this exists.
// ============================================================================
extension SettingsView {

    /// The Dev Debug section: hidden until unlocked by a long-press on the
    /// version footer, or shown automatically for the configured owner. Add more
    /// dev toggles here as needed (perf overlays, feature flags, etc.).
    @ViewBuilder
    var devDebugSection: some View {
        if devDebugUnlocked || devDebugIsOwner {
            Section {
                Toggle(isOn: $devForceShowOwnerUI) {
                    Text("Show Daddy's Tools")
                        .dodFont(DODType.body)
                        .foregroundStyle(DODColor.label)
                }
                .tint(DODColor.burntOrange)
                .accessibilityIdentifier("dev-debug-show-owner-ui")
            } header: {
                Text("Dev Debug")
                    .dodFont(DODType.heading)
                    .foregroundStyle(DODColor.label)
            } footer: {
                Text(
                    "Developer only. Forces the owner \u{201C}Daddy\u{2019}s Tools\u{201D} UI to show "
                        + "for design review. It reveals the icons, it does not grant owner "
                        + "actions. Remove this section before any public release."
                )
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
            }
            .listRowBackground(DODColor.surfaceElevated)
        }
    }
}

extension View {
    /// ⚠️ DEV DEBUG (strip before public release) — hidden unlock: a long-press
    /// on the Settings version footer reveals/hides the Dev Debug section (Dad +
    /// Spencer). Turning it off also clears the force-show-owner-UI toggle.
    func devDebugFooterUnlock(unlocked: Binding<Bool>, forceShowOwnerUI: Binding<Bool>) -> some View {
        onLongPressGesture(minimumDuration: 1.2) {
            unlocked.wrappedValue.toggle()
            if !unlocked.wrappedValue { forceShowOwnerUI.wrappedValue = false }
        }
    }
}

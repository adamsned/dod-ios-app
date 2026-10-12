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

                Button {
                    fireDevPopup(.devFireSaveToast)
                } label: {
                    devTestRow("Fire Save Toast", systemImage: "bookmark.fill")
                }
                .accessibilityIdentifier("dev-debug-fire-save-toast")

                Button {
                    fireDevPopup(.devFireOfflineToast)
                } label: {
                    devTestRow("Fire Offline Toast", systemImage: "wifi.slash")
                }
                .accessibilityIdentifier("dev-debug-fire-offline-toast")

                Button {
                    fireDevPopup(.devLaunchWelcome)
                } label: {
                    devTestRow("Launch Welcome Screen", systemImage: "hand.wave.fill")
                }
                .accessibilityIdentifier("dev-debug-launch-welcome")
            } header: {
                Text("Dev Debug")
                    .dodFont(DODType.heading)
                    .foregroundStyle(DODColor.label)
            } footer: {
                Text(
                    "Developer only. \u{201C}Show Daddy\u{2019}s Tools\u{201D} forces the owner UI "
                        + "for design review (reveals icons, grants nothing). The buttons fire "
                        + "each transient popup over the app so you can review it on demand "
                        + "(handy for checking a theme); they close Settings first. Remove this "
                        + "section before any public release."
                )
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
            }
            .listRowBackground(DODColor.surfaceElevated)
        }
    }

    /// One Dev Debug ▸ Testing button row: a burnt-orange SF Symbol + label.
    private func devTestRow(_ title: String, systemImage: String) -> some View {
        HStack(spacing: DODSpacing.sm) {
            Image(systemName: systemImage)
                .foregroundStyle(DODColor.burntOrange)
            Text(title)
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.label)
        }
    }

    /// Dismiss Settings, then post the dev popup notification once the sheet has
    /// finished animating out — so the popup fires over the main app (and the
    /// App Welcome cover doesn't collide with the still-presented sheet). The
    /// app-level `DevPopupHarness` observes and renders it.
    private func fireDevPopup(_ name: Notification.Name) {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            NotificationCenter.default.post(name: name, object: nil)
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

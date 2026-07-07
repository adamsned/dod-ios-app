import SwiftUI

/// DUT-551 (CL-306) — the shared Settings gear that lives in the trailing slot
/// of every main tab's ``DODScreenHeader`` (Recipes, Saved, Cooking Tools,
/// Search). Settings left the tab bar; this gear opens it as a sheet via the
/// injected `action`. `.title2` (bigger than the prior default-body gear) so it
/// reads as a first-class header affordance on every tab identically.
public struct DODHeaderGearButton: View {

    private let accessibilityID: String
    private let action: () -> Void

    /// `accessibilityID` defaults to the shared `header-settings-gear`, but the
    /// Feed passes its long-standing `feed-toolbar-settings` id (the SmokeTests +
    /// AppShell E2E journeys query it) so the identifier is set directly on the
    /// button, not layered on as an ambiguous outer override.
    public init(accessibilityID: String = "header-settings-gear", action: @escaping () -> Void) {
        self.accessibilityID = accessibilityID
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: "gearshape")
                .font(.title2)
                .accessibilityLabel("Settings")
                // DUT-694 (PR-C): the `.title2` glyph alone is only a ~22pt tap
                // target. Pad the label to the 44pt HIG minimum and make the
                // whole frame hittable so the Settings entry (present on all 4
                // tabs) is comfortably tappable.
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .tint(DODColor.burntOrange)
        .accessibilityIdentifier(accessibilityID)
    }
}

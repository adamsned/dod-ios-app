import SwiftUI

/// DUT-551 (CL-306) — the shared Settings gear that lives in the trailing slot
/// of every main tab's ``DODScreenHeader`` (Recipes, Saved, Cooking Tools,
/// Search). Settings left the tab bar; this gear opens it as a sheet via the
/// injected `action`. `.title2` (bigger than the prior default-body gear) so it
/// reads as a first-class header affordance on every tab identically.
public struct DODHeaderGearButton: View {

    private let action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: "gearshape")
                .font(.title2)
                .accessibilityLabel("Settings")
        }
        .tint(DODColor.burntOrange)
        .accessibilityIdentifier("header-settings-gear")
    }
}

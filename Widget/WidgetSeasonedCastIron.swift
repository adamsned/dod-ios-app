import DODDesignSystem
import DODSupport
import SwiftUI

/// v2 "Seasoned Cast Iron" → widgets. Applies the true-OLED Seasoned Cast Iron
/// theme to a home-screen widget when the user opted in (Settings ▸ Appearance ▸
/// Seasoned Cast Iron ▸ "Applies to Widgets"), read across the process boundary
/// via ``WidgetAppearanceBridge``.
///
/// The widget process follows the SYSTEM light/dark trait and doesn't see the
/// app's in-app appearance override, so when opted in this: (1) flips the
/// `DODColor.isOLEDDark` process-global (set in the modifier's `init`, before
/// color resolution), and (2) forces the subtree to the dark trait — together
/// making `DODColor.surface` / `surfaceElevated` (used in each widget's
/// `containerBackground`) resolve to their OLED hexes, so the widget background
/// matches the in-app Seasoned Cast Iron look instead of Cocoa/Flour.
///
/// NOTE: the App Group read only works in a SIGNED build (an unsigned CLI build
/// drops the entitlement), so verify on an Xcode-signed run.
private struct WidgetSeasonedCastIronModifier: ViewModifier {
    private let enabled: Bool

    init() {
        let on = WidgetAppearanceBridge.widgetsUseSeasonedCastIron()
        enabled = on
        // Set per render (the modifier is rebuilt each render), before the
        // container background's dynamic colors resolve.
        DODColor.isOLEDDark = on
    }

    func body(content: Content) -> some View {
        if enabled {
            content.environment(\.colorScheme, .dark)
        } else {
            content
        }
    }
}

extension View {
    /// Apply the opted-in Seasoned Cast Iron (OLED) theme to a home-screen widget.
    func dodWidgetSeasonedCastIron() -> some View {
        modifier(WidgetSeasonedCastIronModifier())
    }
}

import Foundation

#if canImport(WidgetKit)
import WidgetKit
#endif

/// v2 "Seasoned Cast Iron" → widgets. Bridges the app's "Applies to Widgets"
/// choice across the process boundary to the widget extension via the shared
/// App Group, so a widget (a separate process that follows the SYSTEM light/dark
/// trait and can't see the app's in-app appearance override or the
/// `DODColor.isOLEDDark` process-global) can paint the true-OLED Seasoned Cast
/// Iron background instead of the Cocoa/Flour asset colors.
///
/// The app writes the DERIVED flag (appearance == Seasoned Cast Iron AND the
/// user opted widgets in) and reloads timelines; the widget reads it at render
/// time. Kept as one shared bool so the widget stays trivial.
///
/// NOTE: the App Group only works in a properly SIGNED build (an unsigned
/// `xcodebuild` CLI build drops the App Group entitlement, so the widget can't
/// read this) — verify on an Xcode-signed run.
public enum WidgetAppearanceBridge {

    /// App Group key: whether widgets should adopt the true-OLED Seasoned Cast
    /// Iron background/theme.
    public static let seasonedCastIronKey = "dod.appearance.widgetsUseSeasonedCastIron"

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: WidgetSnapshotConfig.appGroupIdentifier)
    }

    /// App side — persist the derived flag to the App Group and reload widget
    /// timelines so they re-render with the new background. Call whenever the
    /// appearance OR the "Applies to Widgets" toggle changes.
    public static func setWidgetsUseSeasonedCastIron(_ enabled: Bool) {
        sharedDefaults?.set(enabled, forKey: seasonedCastIronKey)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    /// Widget side — whether to paint the Seasoned Cast Iron (OLED) background.
    /// `false` when the App Group is unavailable (e.g. an unsigned build), so
    /// widgets fall back to the normal Cocoa/Flour surface.
    public static func widgetsUseSeasonedCastIron() -> Bool {
        sharedDefaults?.bool(forKey: seasonedCastIronKey) ?? false
    }
}

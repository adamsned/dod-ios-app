import Foundation
import SwiftUI
import Testing

@testable import DODFeatureFeed

/// L1 coverage for the v2 "Seasoned Cast Iron" true-OLED dark theme added to
/// ``AppearancePreference``. Extracted from `SettingsViewModelTests` so that
/// file stays under the SwiftLint 400-line `file_length` cap.
///
/// Spec trace: US-36 AC-36.2 (App Appearance), v2 OLED theme.
@Suite("AppearancePreference — Seasoned Cast Iron (v2)") struct AppearancePreferenceTests {

    /// The third theme is a distinct case with its own label, forces the dark
    /// trait (it's a dark theme), and is the ONLY case that flags OLED — every
    /// other case (crucially "Cocoa" `.dark`) leaves the surface tokens on their
    /// asset-catalog values.
    @Test func seasonedCastIronThemeMetadata() {
        #expect(AppearancePreference.seasonedCastIron.displayName == "Seasoned Cast Iron")
        #expect(AppearancePreference.seasonedCastIron.colorScheme == .dark)
        #expect(AppearancePreference.seasonedCastIron.isOLEDDark == true)
        #expect(AppearancePreference.seasonedCastIron.rawValue == "seasonedCastIron")

        // Only the OLED theme flips the flag; the rest (including Cocoa) don't.
        for value in AppearancePreference.allCases where value != .seasonedCastIron {
            #expect(value.isOLEDDark == false)
        }
    }

    /// The picker now offers FOUR themes and the new raw value round-trips
    /// through the defaults-backed read path RootView + DODApp use at launch.
    @Test func seasonedCastIronIsIncludedAndPersists() {
        #expect(AppearancePreference.allCases.count == 4)
        #expect(AppearancePreference.allCases.contains(.seasonedCastIron))

        let suiteName = "AppearancePreferenceTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(
            AppearancePreference.seasonedCastIron.rawValue,
            forKey: SettingsViewModel.appearancePreferenceKey
        )
        #expect(AppearancePreference.fromDefaults(defaults) == .seasonedCastIron)
    }

    /// A malformed / unknown raw value still falls back to `.system` even now
    /// that a fourth case exists — the defensive read path is unchanged.
    @Test func unknownRawValueStillFallsBackToSystem() {
        let suiteName = "AppearancePreferenceTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set("charcoal", forKey: SettingsViewModel.appearancePreferenceKey)
        #expect(AppearancePreference.fromDefaults(defaults) == .system)
    }
}

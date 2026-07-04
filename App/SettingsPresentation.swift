import DODFeatureFeed
import SwiftUI

/// T-912 / DUT-551 (CL-306) — Settings presentation helpers, shared by the
/// iPhone header gear (`FeedView` → `onOpenSettings` → `RootView.showSettingsSheet`)
/// and the iPad sidebar Settings row, so both build the `SettingsViewModel`
/// identically.
///
/// Settings left the tab bar in this change (it was a first-class tab since
/// T-823 / DUT-187); it is now reached from a `gearshape` button in the Feed
/// header (iPhone) or an untagged sidebar row (iPad), presented as a `.sheet`
/// wrapping `SettingsView` in a `NavigationStack`. The dependency surface is
/// exactly what the retired `TabStack.settingsTabViewModel` wired: the
/// iCloud-Sync seam, the AVFoundation voice previewer, the Keychain profile +
/// photo stores, and the notification-auth closure.
extension AppDependencies {

    /// Build the `SettingsViewModel` the Settings sheet renders. Preserves the
    /// `#if canImport(UIKit)` branch verbatim from the old `TabStack`
    /// construction (the macOS test slice omits the `profilePhotoStore` arg).
    func settingsSheetViewModel() -> SettingsViewModel {
        #if canImport(UIKit)
        SettingsViewModel(
            dependencies: settingsDependencies(),
            voicePreviewer: SystemVoicePreviewer(),
            profileStore: profileStore,
            profilePhotoStore: profilePhotoStore,
            requestNotificationAuthorization: {
                await self.notificationService.requestAuthorization()
            }
        )
        #else
        SettingsViewModel(
            dependencies: settingsDependencies(),
            voicePreviewer: SystemVoicePreviewer(),
            profileStore: profileStore,
            requestNotificationAuthorization: {
                await self.notificationService.requestAuthorization()
            }
        )
        #endif
    }
}

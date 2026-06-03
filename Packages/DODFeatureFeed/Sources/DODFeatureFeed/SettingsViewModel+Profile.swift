import DODFeatureProfile
import Foundation

// US-44 Phase b (T-740) — Phase b photo store collaborator + the
// iOS-only convenience init that threads it through.
//
// Extracted from `SettingsViewModel.swift` so that file stays under the
// SwiftLint 400-line file_length cap. The split mirrors the same
// `+CloudSync.swift` / `+Voice.swift` per-topic extension pattern the
// rest of the view-model already uses.
//
// Spec trace: US-44 AC-44.3, AC-44.9; CL-137.

#if canImport(UIKit)
extension SettingsViewModel {

    /// iOS-only convenience init that threads in the Phase b
    /// ``ProfilePhotoStoring`` collaborator alongside the Phase a
    /// ``ProfileStoring``. Delegates to the designated init and then
    /// assigns the photo store post-super so the rest of the
    /// view-model surface stays single-init.
    public convenience init(
        defaults: UserDefaults = .standard,
        dependencies: (any SettingsDependencies)? = nil,
        voicePreviewer: (any VoicePreviewing)? = nil,
        voiceLocale: Locale = .current,
        profileStore: (any ProfileStoring)? = nil,
        profilePhotoStore: (any ProfilePhotoStoring)?,
        initialProfile: UserProfile? = nil,
        requestNotificationAuthorization: @escaping @MainActor () async -> Bool = { false }
    ) {
        self.init(
            defaults: defaults,
            dependencies: dependencies,
            voicePreviewer: voicePreviewer,
            voiceLocale: voiceLocale,
            profileStore: profileStore,
            initialProfile: initialProfile,
            requestNotificationAuthorization: requestNotificationAuthorization
        )
        self.profilePhotoStore = profilePhotoStore
    }
}
#endif

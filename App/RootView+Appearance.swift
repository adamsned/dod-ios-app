import DODFeatureFeed
import SwiftUI

// US-36 AC-36.2 — appearance-preference decoding + mapping, extracted from
// `RootView.swift` so that file stays under the SwiftLint `file_length` cap.
extension RootView {

    /// Decode the `@AppStorage`-backed raw value into a typed enum. An
    /// absent / malformed value falls back to `.system` so users always
    /// see a sensible default — same defensive fallback
    /// `AppearancePreference.fromDefaults(_:)` implements for the non-`@AppStorage` path.
    var appearance: AppearancePreference {
        AppearancePreference(rawValue: appearanceRaw) ?? .system
    }

    /// Map the user-selected preference onto SwiftUI's `ColorScheme?`. `.system`
    /// returns `nil` so `.preferredColorScheme(...)` is a no-op and the OS drives
    /// every screen. T-756 / CL-153 — delegates to the shared
    /// ``AppearancePreference/colorScheme`` (RootView + SettingsView agree).
    func preferredColorScheme(for value: AppearancePreference) -> ColorScheme? {
        value.colorScheme
    }
}

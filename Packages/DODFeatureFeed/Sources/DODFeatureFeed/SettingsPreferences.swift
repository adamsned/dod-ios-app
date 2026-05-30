import Foundation

// The Settings preference value types (`AppearancePreference`,
// `ShareFormatPreference`) were extracted from `SettingsViewModel.swift`
// to keep that file under the SwiftLint 400-line `file_length` cap after
// T-721 added the Cook Mode voice-gender row. No behavior change — these
// are the same public enums the view-model's `appearance` / `shareFormat`
// accessors read + write, just hosted beside the view-model rather than
// inside its file.

// MARK: - Appearance preference (AC-36.2)

/// User-selected appearance preference. Drives `RootView`'s
/// `.preferredColorScheme(...)` modifier: `.system` leaves the modifier's
/// value `nil` (so the OS-level setting wins), `.light` / `.dark` force
/// the SwiftUI environment value regardless of OS preference.
///
/// Raw values are the on-disk wire format — never rename without a
/// migration shim because the values land in `UserDefaults` on every
/// user's device that has touched the Appearance picker.
///
/// Spec trace: US-36 AC-36.2.
public enum AppearancePreference: String, CaseIterable, Sendable, Hashable {
    case system
    case light
    case dark

    /// Human-readable label rendered in the picker row.
    public var displayName: String {
        switch self {
        case .system: "Match System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    /// Default-aware read. An absent key OR an unknown raw value falls
    /// back to ``system`` so a malformed migration / forward-compat
    /// situation never crashes — Match System is the safe default.
    public static func fromDefaults(_ defaults: UserDefaults) -> AppearancePreference {
        guard
            let raw = defaults.string(forKey: SettingsViewModel.appearancePreferenceKey),
            let value = AppearancePreference(rawValue: raw)
        else {
            return .system
        }
        return value
    }
}

// MARK: - Share format preference (AC-36.3)

/// Default share format preference. Today the recipe-detail share path
/// (`RecipeDetailView.ShareLink`) emits the canonical URL only —
/// ``linkOnly`` preserves that AC-6.2 behavior byte-for-byte. The
/// ``linkAndText`` case is persisted but not yet consumed: a future
/// task wires the recipe excerpt into the share payload.
///
/// Raw values are the on-disk wire format — same caveat as
/// ``AppearancePreference``: don't rename without a migration shim.
///
/// Spec trace: US-36 AC-36.3.
public enum ShareFormatPreference: String, CaseIterable, Sendable, Hashable {
    case linkOnly
    case linkAndText

    /// Human-readable label rendered in the picker row.
    public var displayName: String {
        switch self {
        case .linkOnly: "Just the link"
        case .linkAndText: "Link + recipe text"
        }
    }

    /// Default-aware read. Absent / malformed values fall back to
    /// ``linkOnly`` — the existing AC-6.2 share contract.
    public static func fromDefaults(_ defaults: UserDefaults) -> ShareFormatPreference {
        guard
            let raw = defaults.string(forKey: SettingsViewModel.shareFormatPreferenceKey),
            let value = ShareFormatPreference(rawValue: raw)
        else {
            return .linkOnly
        }
        return value
    }
}

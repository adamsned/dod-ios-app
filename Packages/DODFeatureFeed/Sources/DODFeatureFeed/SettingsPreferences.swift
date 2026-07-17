import DODSupport
import Foundation
import SwiftUI

// The Settings preference value types (`AppearancePreference`,
// `ShareFormatPreference`, `TemperaturePreference`) were extracted from
// `SettingsViewModel.swift` to keep that file under the SwiftLint 400-line
// `file_length` cap after T-721 added the Cook Mode voice-gender row. No
// behavior change — these are the same public enums the view-model's
// `appearance` / `shareFormat` / `temperaturePreference` accessors read +
// write, just hosted beside the view-model rather than inside its file.

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
    /// A THIRD, true-OLED dark theme (v2). Deep black `#000000` background with
    /// slightly-lighter-gray elevated surfaces; cream text + burnt-orange accent
    /// carry over from ``dark`` ("Cocoa") unchanged. It does NOT replace Cocoa —
    /// Cocoa stays the default dark. iOS only exposes light/dark traits, so a
    /// second dark theme can't be a new asset appearance; instead this maps to
    /// the `.dark` `colorScheme` and flips ``isOLEDDark``, which the app hands to
    /// `DODColor.isOLEDDark` so the four surface tokens resolve to OLED hexes
    /// under the dark trait. Raw value "seasonedCastIron" is the persisted wire
    /// format — never rename without a migration shim.
    case seasonedCastIron

    /// Human-readable label rendered in the picker row. T-763 / CL-160
    /// (DUT-69) — the two explicit-scheme labels carry brand personality:
    /// `.light` → "Flour", `.dark` → "Cocoa" (the `rawValue`s + the
    /// `colorScheme` mapping are unchanged, so a saved preference is
    /// preserved). "Match System" stays plain. v2 adds `.seasonedCastIron`
    /// → "Seasoned Cast Iron" (the true-OLED dark theme).
    public var displayName: String {
        switch self {
        case .system: "Match System"
        case .light: "Flour"
        case .dark: "Cocoa"
        case .seasonedCastIron: "Seasoned Cast Iron"
        }
    }

    /// T-756 / CL-153 — the `ColorScheme?` this preference maps to for
    /// `.preferredColorScheme(...)`: `.system` → `nil` (inherit the OS
    /// setting), `.light` / `.dark` → the forced scheme. Single source of
    /// truth reused by both `RootView` (main window) and `SettingsView`
    /// (the Settings sheet's own live theme — fixes DUT-62 bug 2).
    /// `.seasonedCastIron` is a dark theme, so it forces `.dark` — the OLED
    /// surface swap is layered on top via ``isOLEDDark`` (there is no distinct
    /// iOS trait for a second dark appearance).
    public var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark, .seasonedCastIron: .dark
        }
    }

    /// v2 — whether this preference is the true-OLED "Seasoned Cast Iron"
    /// theme. The app reads this and sets `DODColor.isOLEDDark` (a plain
    /// process-global in DODDesignSystem, which cannot import this module) so
    /// the four background/surface tokens resolve to their OLED hexes under the
    /// dark trait. Every other case (including "Cocoa") is `false`, leaving the
    /// asset-catalog dark values untouched.
    public var isOLEDDark: Bool { self == .seasonedCastIron }

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

// MARK: - Temperature preference (DUT-47, temperature half)

/// User-selected display unit for temperatures inside recipe instruction
/// text. Drives Recipe Detail's render-time call to
/// ``DODSupport/TemperatureConverter/converting(_:to:)``:
/// - ``recipeDefault`` — leave temperatures exactly as the recipe author
///   wrote them (the converter is NOT applied). The first-launch default.
/// - ``fahrenheit`` / ``celsius`` — rewrite explicit-unit temperatures in
///   the step text to that scale at display time (stored data is never
///   mutated, mirroring how servings scaling is a render-time transform).
///
/// Raw values are the on-disk wire format — never rename without a
/// migration shim because the values land in `UserDefaults` on every
/// device that has touched the Temperature picker (same caveat as
/// ``AppearancePreference`` / ``ShareFormatPreference``).
///
/// Scope note: this is the temperature half of DUT-47. The ingredient
/// metric/imperial conversion is deferred — it needs DUT-43's quantity
/// parser — and is intentionally not modeled here.
///
/// Spec trace: DUT-47 (temperature half).
public enum TemperaturePreference: String, CaseIterable, Sendable, Hashable {
    case recipeDefault
    case fahrenheit
    case celsius

    /// Human-readable label rendered in the picker row.
    public var displayName: String {
        switch self {
        case .recipeDefault: "Recipe Default"
        case .fahrenheit: "Fahrenheit"
        case .celsius: "Celsius"
        }
    }

    /// The converter unit this preference drives, or `nil` for
    /// ``recipeDefault`` (the signal to skip conversion entirely). Recipe
    /// Detail reads this and only runs the converter when it is non-`nil`.
    public var targetUnit: TemperatureUnit? {
        switch self {
        case .recipeDefault: nil
        case .fahrenheit: .fahrenheit
        case .celsius: .celsius
        }
    }

    /// Default-aware read. An absent key OR an unknown raw value falls back
    /// to ``recipeDefault`` so a malformed migration / forward-compat
    /// situation never crashes — "show as written" is the safe default.
    public static func fromDefaults(_ defaults: UserDefaults) -> TemperaturePreference {
        guard
            let raw = defaults.string(forKey: SettingsViewModel.temperaturePreferenceKey),
            let value = TemperaturePreference(rawValue: raw)
        else {
            return .recipeDefault
        }
        return value
    }
}

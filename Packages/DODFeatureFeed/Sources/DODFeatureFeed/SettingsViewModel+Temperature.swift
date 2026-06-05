import DODSupport
import Foundation

/// DUT-47 (temperature half) — the Settings "Recipe step temperatures"
/// preference key + accessor.
///
/// Extracted from `SettingsViewModel.swift` so that file stays under the
/// SwiftLint 400-line `file_length` cap (the same split
/// `SettingsViewModel+Voice.swift` / `SettingsViewModel+CloudSync.swift`
/// follow). The `defaults` store lives on the primary declaration; this
/// extension only adds the one persisted preference.
///
/// Spec trace: DUT-47 (temperature half).
extension SettingsViewModel {

    /// DUT-47 — Recipe-step temperature display preference key. Value is the
    /// raw value of ``TemperaturePreference`` (`"recipeDefault"` /
    /// `"fahrenheit"` / `"celsius"`). Defaults to `.recipeDefault` (no
    /// conversion — temperatures render as the recipe author wrote them).
    ///
    /// Aliases ``DODSupport/TemperatureConverter/preferenceKey`` — the
    /// canonical key lives in the shared layer next to the Recipe Detail
    /// reader (per the CloudKit-key precedent) so Settings and Recipe Detail
    /// agree on the wire format without a feature-to-feature dependency. The
    /// `nonisolated static` alias is kept so call sites read symmetrically
    /// with `appearancePreferenceKey` / `shareFormatPreferenceKey`.
    public nonisolated static let temperaturePreferenceKey = TemperatureConverter.preferenceKey

    /// DUT-47. Defaults to ``TemperaturePreference/recipeDefault`` when the
    /// key is absent or carries a value that doesn't decode to a known case
    /// (defensive — preserves "show as written" under any future rename or
    /// migration). Recipe Detail consumes the persisted value at render time
    /// through the same key via `@AppStorage`; a change here is honored the
    /// next time the instructions section re-renders.
    public var temperaturePreference: TemperaturePreference {
        get { TemperaturePreference.fromDefaults(defaults) }
        set { defaults.set(newValue.rawValue, forKey: Self.temperaturePreferenceKey) }
    }
}

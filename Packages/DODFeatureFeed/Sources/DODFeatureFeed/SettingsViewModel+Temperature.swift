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

    // T-756 / CL-153 — the `temperaturePreference` property itself moved to
    // the primary `SettingsViewModel` declaration: it's now an `@Observable`
    // STORED property (was computed-over-defaults here), and stored
    // properties can't live in an extension. Only the key alias stays here.
}

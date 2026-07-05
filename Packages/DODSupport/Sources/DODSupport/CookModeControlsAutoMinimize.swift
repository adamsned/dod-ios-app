import Foundation

/// DUT-596 — the shared "Auto Minimize Cook Mode Controls After" preference.
///
/// Cook Mode's player controls dim/collapse after this many idle seconds so
/// more step text shows; any interaction restores them instantly. Both the
/// Cook Mode view (`DODFeatureRecipeDetail`) and the App Settings picker
/// (`DODFeatureFeed`) read this via `@AppStorage(preferenceKey)`, so the
/// key + option set + labels live here in `DODSupport` (like
/// ``TemperatureConverter/preferenceKey`` and
/// ``IngredientMetricConverter/preferenceKey``) rather than being duplicated.
///
/// The stored value is the idle delay in whole seconds. `0` means **Never**
/// auto-minimize. The default (used as the `@AppStorage` default value) is
/// ``defaultSeconds`` (5).
public enum CookModeControlsAutoMinimize {

    /// `UserDefaults` / `@AppStorage` key for the idle delay, in seconds.
    public static let preferenceKey = "dod.settings.cookModeControlsAutoMinimizeSeconds"

    /// The idle delay (seconds) picked by default when the user hasn't chosen
    /// one. Also the value both `@AppStorage` sites seed themselves with.
    public static let defaultSeconds = 5

    /// Selectable delays, in seconds, shown in the Settings picker. `0` == Never.
    public static let options: [Int] = [0, 3, 5, 10]

    /// The user-facing label for a delay value. `0` reads "Never"; every other
    /// value reads "N Seconds" (Title Case for the Settings picker row values).
    public static func label(for seconds: Int) -> String {
        seconds <= 0 ? "Never" : "\(seconds) Seconds"
    }

    /// Whether the controls should auto-minimize at all for a given delay — a
    /// pure decision helper so the scheduling logic stays testable without a
    /// timer. `false` for `Never` (0) or any non-positive value.
    public static func shouldAutoMinimize(afterSeconds seconds: Int) -> Bool {
        seconds > 0
    }
}

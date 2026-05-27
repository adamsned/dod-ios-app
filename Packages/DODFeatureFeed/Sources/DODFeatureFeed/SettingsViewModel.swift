import Foundation
import Observation

/// State + persistence for the Settings page (US-32, T-550 skeleton).
///
/// v1 owns exactly one piece of persisted state: the "Use metric units"
/// toggle, stored in `UserDefaults` under ``Self/useMetricUnitsKey``. The
/// actual ingredient-conversion path that consumes this flag is the T-551
/// follow-up; this view-model ships only the read/write round-trip so
/// the toggle UI lands with a working persistence contract.
///
/// `UserDefaults` is constructor-injected so the L1 unit suite can pass
/// an isolated suite (`UserDefaults(suiteName:)`) without polluting the
/// shared standard defaults — pattern mirrors `RecentSearches` in
/// `DODFeatureSearch`.
///
/// Spec trace: US-32 AC-32.4 (toggle persists to UserDefaults).
@Observable
@MainActor
public final class SettingsViewModel {

    /// UserDefaults key for the "Use metric units" toggle. Namespaced
    /// `dod.settings.*` so other settings rows (T-551 conversions wiring,
    /// future preferences) can append cleanly under the same prefix.
    public static let useMetricUnitsKey = "dod.settings.useMetricUnits"

    private let defaults: UserDefaults

    /// Backing store for ``useMetricUnits``. Reads + writes UserDefaults
    /// on every access so a parallel write from another surface (e.g.
    /// a future Settings sync feature) is observed on the next read.
    public var useMetricUnits: Bool {
        get { defaults.bool(forKey: Self.useMetricUnitsKey) }
        set { defaults.set(newValue, forKey: Self.useMetricUnitsKey) }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Version footer

    /// Display string for the version footer row, e.g. `"v1.0.2 (47)"`.
    /// Reads `CFBundleShortVersionString` + `CFBundleVersion` from the
    /// supplied bundle (defaults to `Bundle.main` in production; tests
    /// pass a fixture bundle if they want deterministic strings).
    ///
    /// Spec trace: US-32 AC-32.3 row 3.
    public static func versionFooter(bundle: Bundle = .main) -> String {
        let info = bundle.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "—"
        let build = info["CFBundleVersion"] as? String ?? "—"
        return "v\(version) (\(build))"
    }
}

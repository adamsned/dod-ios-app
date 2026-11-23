import DODSupport
import Foundation

/// DUT-2903 — pure copy helpers for ``CookModeProbeStrip``.
enum CookModeProbeStripText {
    /// "165°F", or "--" when there is no (finite) reading.
    static func temperature(_ fahrenheit: Double?) -> String {
        guard let fahrenheit, fahrenheit.isFinite else { return "--" }
        return "\(Int(exactly: fahrenheit.rounded()) ?? 0)°F"
    }
}

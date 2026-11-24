import DODSupport
import Foundation

/// DUT-2903 — pure copy helpers for ``CookModeProbeStrip``.
enum CookModeProbeStripText {
    /// "165°F", or "--" when there is no (finite) reading.
    static func temperature(_ fahrenheit: Double?) -> String {
        guard let fahrenheit, fahrenheit.isFinite else { return "--" }
        return "\(Int(exactly: fahrenheit.rounded()) ?? 0)°F"
    }

    /// "Target 165°F", or "No target set" before one is chosen.
    static func targetLabel(_ targetF: Double?) -> String {
        guard let targetF else { return "No target set" }
        return "Target \(temperature(targetF))"
    }

    /// One status line per connection state.
    static func connectionLine(_ state: ProbeConnectionState) -> String {
        switch state {
        case .idle: return "Probe not connected"
        case .scanning: return "Looking for your probe…"
        case .connecting: return "Connecting to probe…"
        case .connected: return "Probe connected"
        case .outOfRange: return "Probe out of range — move closer"
        case .lost: return "Probe connection lost — enter temperature manually"
        case .unauthorized: return "Bluetooth access is off — enter temperature manually"
        }
    }

    /// Parses the manual-entry field; nil unless it is a plausible °F value (0 < value < 600).
    static func parseManual(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard let value = Double(trimmed), value.isFinite, value > 0, value < 600 else { return nil }
        return value
    }
}

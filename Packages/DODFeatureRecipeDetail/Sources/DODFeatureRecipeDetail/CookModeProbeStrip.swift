import DODDesignSystem
import DODSupport
import Foundation
import SwiftUI

/// DUT-2903 — Cook Mode's Bluetooth meat-probe strip (view only).
struct CookModeProbeStrip: View {
    let session: ProbeSession
    let recipeID: Int

    private var targetBinding: Binding<Double> {
        Binding(
            get: { session.targetF ?? 165 },
            set: { session.setTarget($0, recipeID: recipeID) }
        )
    }

    private var targetStepper: some View {
        Stepper(value: targetBinding, in: 100...250, step: 5) {
            Text(CookModeProbeStripText.targetLabel(session.targetF))
                .dodFont(DODType.detail)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DODSpacing.xs) {
            readout
            statusLine
            banner
            targetStepper
        }
        .padding(.horizontal, DODSpacing.md)
        .padding(.vertical, DODSpacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var banner: some View {
        if let text = session.bannerText {
            Text(text)
                .dodFont(DODType.detail)
                .foregroundStyle(DODColor.burntOrange)
        }
    }

    private var statusLine: some View {
        Text(CookModeProbeStripText.connectionLine(session.connection))
            .dodFont(DODType.caption)
            .foregroundStyle(DODColor.labelSecondary)
    }

    private var readout: some View {
        HStack(spacing: DODSpacing.md) {
            Text("Internal \(CookModeProbeStripText.temperature(session.reading?.internalF))")
                .dodFont(DODType.heading)
                .foregroundStyle(DODColor.burntOrange)
            Text("Ambient \(CookModeProbeStripText.temperature(session.reading?.ambientF))")
                .dodFont(DODType.detail)
                .foregroundStyle(DODColor.labelSecondary)
        }
        .monospacedDigit()
    }
}

/// DUT-2903 — pure copy helpers for ``CookModeProbeStrip``.
enum CookModeProbeStripText {
    /// "165°F", or "--" when there is no (finite) reading.
    static func temperature(_ fahrenheit: Double?) -> String {
        guard let fahrenheit, fahrenheit.isFinite else { return "--" }
        let rounded = fahrenheit.rounded()
        // Use a more explicit approach to avoid potential Int(exactly:) issues
        if let intVal = Int(exactly: rounded) {
            return "\(intVal)°F"
        } else {
            // Fallback for edge cases
            return "\(Int(rounded))°F"
        }
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

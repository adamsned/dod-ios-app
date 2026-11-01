import DODSupport
import Foundation
import Observation

/// DUT-135 — live meat-probe state for Cook Mode. A separate class because an
/// extension of `CookModeViewModel` cannot add stored properties.
@Observable
@MainActor
public final class ProbeSession {
    public private(set) var reading: ProbeReading?
    public private(set) var targetF: Double?
    public private(set) var evaluator: ProbeAlertEvaluator?
    public private(set) var bannerText: String?
    public var manualEntryF: Double?
    public var connection: ProbeConnectionState = .idle
    /// Called for each alert `ingest` raises; a later ticket wires it to the local notification.
    public var onAlert: ((ProbeAlert) -> Void)?

    public init() {}

    public func setTarget(_ fahrenheit: Double, recipeID: Int, store: ProbeTargetStore = ProbeTargetStore()) {
        targetF = fahrenheit
        evaluator = ProbeAlertEvaluator(targetF: fahrenheit)
        store.setTarget(fahrenheit, forRecipe: recipeID)
    }

    /// Seed from the stored target; otherwise `defaultF` (the recipe doneness guidance, nil if none).
    public func seedTarget(recipeID: Int, defaultF: Double?, store: ProbeTargetStore = ProbeTargetStore()) {
        if let fahrenheit = store.target(forRecipe: recipeID) ?? defaultF {
            targetF = fahrenheit
            evaluator = ProbeAlertEvaluator(targetF: fahrenheit)
        }
    }

    /// Feed a probe reading or a manual entry (manual fallback).
    public func ingest(_ probeReading: ProbeReading) {
        reading = probeReading
        guard let alert = evaluator?.evaluate(probeReading) else { return }
        switch alert {
        case .nearTarget: bannerText = "Almost there — \(Int(probeReading.internalF))°F"
        case .targetReached: bannerText = "Target reached — \(Int(probeReading.internalF))°F"
        }
        onAlert?(alert)
    }

    public func ingestManual(_ fahrenheit: Double) { ingest(ProbeReading(internalF: fahrenheit)) }
}

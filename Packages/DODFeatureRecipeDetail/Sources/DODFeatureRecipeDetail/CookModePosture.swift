import Foundation

/// DUT-1017 — the physical posture of the device as Cook Mode cares about it.
enum CookModePosture: Equatable {
    case flat  // normal phone, or a fold that is fully open
    case tent  // foldable standing half-open like a tiny cookbook

    /// Half-open hinge range (degrees) that counts as tent mode.
    /// Note: This range (60...120) is a placeholder and will be tuned once the real iOS 27 API is confirmed.
    static let tentAngleRange: ClosedRange<Double> = 60...120

    /// - Parameter hingeAngle: degrees reported by the foldable API, or nil
    ///   when the device has no hinge (every non-fold iPhone and iPad).
    static func resolve(hingeAngle: Double?) -> CookModePosture {
        guard let hingeAngle, tentAngleRange.contains(hingeAngle) else { return .flat }
        return .tent
    }

    /// Whether Cook Mode should render the two-pane layout. The Done card
    /// keeps the normal single-pane layout.
    func usesTwoPane(isFinished: Bool) -> Bool {
        self == .tent && !isFinished
    }
}

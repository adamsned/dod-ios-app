import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

private struct CookModePostureKey: EnvironmentKey {
    static let defaultValue: CookModePosture = .flat
}

extension EnvironmentValues {
    /// DUT-1017 — current foldable posture; `.flat` unless a hinge reports tent.
    var cookModePosture: CookModePosture {
        get { self[CookModePostureKey.self] }
        set { self[CookModePostureKey.self] = newValue }
    }
}

extension View {
    /// Injects the posture. Production passes the hinge angle (in degrees) read
    /// by `CookModeHingeMonitor`; tests and previews pass a fixed angle.
    func cookModePosture(hingeAngle: Double?) -> some View {
        environment(\.cookModePosture, CookModePosture.resolve(hingeAngle: hingeAngle))
    }
}

/// DUT-1017 — the only place that touches the OS foldable API. `hingeAngle` is
/// in degrees and stays nil on devices without a hinge and on OSes before 27.1.
@Observable @MainActor
final class CookModeHingeMonitor {
    private(set) var hingeAngle: Double?

    init() {}

    nonisolated static func degrees(fromRadians radians: Double) -> Double {
        radians * 180 / .pi
    }

    #if canImport(UIKit)
    /// Starts observing the hinge that belongs to `view`'s hierarchy.
    @available(iOS 27.1, *)
    func attach(to view: UIView) {
        let interaction = UIHingeInteraction { [weak self] _, update in
            self?.hingeAngle = update.hinge.map { Self.degrees(fromRadians: Double($0.angle)) }
        }
        view.addInteraction(interaction)
    }
    #endif
}

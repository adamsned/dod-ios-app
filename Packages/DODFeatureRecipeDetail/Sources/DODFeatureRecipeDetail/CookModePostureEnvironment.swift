import SwiftUI

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

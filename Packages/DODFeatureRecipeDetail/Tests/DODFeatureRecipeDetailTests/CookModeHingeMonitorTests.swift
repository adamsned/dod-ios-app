import Testing

@testable import DODFeatureRecipeDetail

@Suite("Cook Mode hinge monitor (DUT-1017)")
struct CookModeHingeMonitorTests {

    @Test @MainActor func hingeAngleIsNilWithoutHinge() {
        #expect(CookModeHingeMonitor().hingeAngle == nil)
    }

    @Test func radiansConvertToDegrees() {
        #expect(abs(CookModeHingeMonitor.degrees(fromRadians: .pi / 2) - 90) < 0.0001)
    }

    @Test func halfTurnResolvesToFlat() {
        let degrees = CookModeHingeMonitor.degrees(fromRadians: .pi)
        #expect(CookModePosture.resolve(hingeAngle: degrees) == .flat)
    }

    @Test func quarterTurnResolvesToTent() {
        let degrees = CookModeHingeMonitor.degrees(fromRadians: .pi / 2)
        #expect(CookModePosture.resolve(hingeAngle: degrees) == .tent)
    }
}

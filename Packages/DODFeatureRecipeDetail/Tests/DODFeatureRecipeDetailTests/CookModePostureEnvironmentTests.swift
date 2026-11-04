import SwiftUI
import Testing

@testable import DODFeatureRecipeDetail

@Suite("Cook Mode posture environment (DUT-1017)")
struct CookModePostureEnvironmentTests {

    @Test func defaultPostureIsFlat() {
        #expect(EnvironmentValues().cookModePosture == .flat)
    }

    @Test func settingTentReadsBackTent() {
        var values = EnvironmentValues()
        values.cookModePosture = .tent
        #expect(values.cookModePosture == .tent)
    }
}

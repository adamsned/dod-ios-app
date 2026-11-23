import Foundation
import Testing

@testable import DODFeatureRecipeDetail

@Suite("Cook Mode probe strip text (DUT-2903)") struct CookModeProbeStripTextTests {
    @Test func temperatureRounds() {
        #expect(CookModeProbeStripText.temperature(164.6) == "165°F")
    }

    @Test func temperatureMissing() {
        #expect(CookModeProbeStripText.temperature(nil) == "--")
        #expect(CookModeProbeStripText.temperature(.nan) == "--")
    }
}

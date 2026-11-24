import DODSupport
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

    @Test func targetLabelSet() {
        #expect(CookModeProbeStripText.targetLabel(165) == "Target 165°F")
    }

    @Test func targetLabelUnset() {
        #expect(CookModeProbeStripText.targetLabel(nil) == "No target set")
    }

    @Test func connectedLine() {
        #expect(CookModeProbeStripText.connectionLine(.connected) == "Probe connected")
    }

    @Test func lostLineMentionsManual() {
        #expect(CookModeProbeStripText.connectionLine(.lost).contains("manually"))
    }

    @Test func parseManualAccepts() {
        #expect(CookModeProbeStripText.parseManual(" 142.5 ") == 142.5)
    }

    @Test func parseManualRejects() {
        #expect(CookModeProbeStripText.parseManual("abc") == nil)
        #expect(CookModeProbeStripText.parseManual("-5") == nil)
        #expect(CookModeProbeStripText.parseManual("900") == nil)
    }
}

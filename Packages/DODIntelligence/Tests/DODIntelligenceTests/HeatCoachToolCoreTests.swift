import DODSupport
import Testing

@testable import DODIntelligence

@Suite("HeatCoachToolCore") struct HeatCoachToolCoreTests {
    @Test func ambientParsingIsCaseInsensitiveAndDefaultsToMild() {
        #expect(HeatCoachToolCore.ambientCondition(from: "HOT") == .hot)
        #expect(HeatCoachToolCore.ambientCondition(from: "cold") == .cold)
        #expect(HeatCoachToolCore.ambientCondition(from: "balmy") == .mild)
    }

    @Test func windyHighAltitudeUsesTrustedMath() {
        let summary = HeatCoachToolCore.adjustment(
            ovenDiameterInches: 12,
            isBaking: false,
            ambient: "mild",
            windy: true,
            elevationFeet: 6000
        )
        #expect(summary.contains("29-30 coals"))
        #expect(summary.contains("every 20 min"))
    }
}

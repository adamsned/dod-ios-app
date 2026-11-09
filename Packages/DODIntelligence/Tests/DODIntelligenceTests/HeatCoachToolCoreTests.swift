import DODSupport
import Testing

@testable import DODIntelligence

@Suite("HeatCoachToolCore") struct HeatCoachToolCoreTests {
    @Test func ambientParsingIsCaseInsensitiveAndDefaultsToMild() {
        #expect(HeatCoachToolCore.ambientCondition(from: "HOT") == .hot)
        #expect(HeatCoachToolCore.ambientCondition(from: "cold") == .cold)
        #expect(HeatCoachToolCore.ambientCondition(from: "balmy") == .mild)
    }
}

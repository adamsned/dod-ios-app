import Testing

@testable import DODSupport

@Suite("HeatCoachGrounding") struct HeatCoachGroundingTests {
    @Test func windyAt6000ft_twelveInch_even() {
        let facts = DutchOvenHeatCoach.groundedFacts(
            ovenDiameterInches: 12,
            style: .even,
            ambient: .mild,
            windy: true,
            elevationFeet: 6000
        )
        #expect(facts.baseline.total == 24)
        #expect(facts.elevationCoalDelta == 2)
        #expect(facts.adjustedTotal == 29...30)
        #expect(facts.cookTimeExtraMinutes == 90...120)
        #expect(facts.replenishMinutes == 20)
    }
    @Test func calmMildSeaLevel_isBaseline() {
        let facts = DutchOvenHeatCoach.groundedFacts(
            ovenDiameterInches: 12,
            style: .baking,
            ambient: .mild,
            windy: false,
            elevationFeet: 0
        )
        #expect(facts.adjustedTotal == 24...24)
        #expect(facts.replenishMinutes == 30)
    }
}

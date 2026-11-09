import DODSupport
import Foundation
import Testing

@Suite("HeatCoachGroundednessEval.allowedNumbers")
struct HeatCoachGroundednessEvalTests {

    @Test func evenStyleAllowsDiameterSplitAndBaseline() {
        let query = HeatCoachQuery(ovenDiameterInches: 12, style: .even, answer: "")
        #expect(HeatCoachGroundednessEval.allowedNumbers(for: query) == [12, 24, 350])
    }

    @Test func includesEverySplitFigureForBakingStyle() {
        let query = HeatCoachQuery(ovenDiameterInches: 12, style: .baking, answer: "")
        let split = DutchOvenHeatCoach.startingCoals(ovenDiameterInches: 12, style: .baking)
        let allowed = HeatCoachGroundednessEval.allowedNumbers(for: query)
        #expect(allowed.isSuperset(of: [12, split.lid, split.bottom, split.total, 350]))
    }

    @Test func rejectsAnUngroundedNumber() {
        let query = HeatCoachQuery(ovenDiameterInches: 12, style: .even, answer: "")
        #expect(!HeatCoachGroundednessEval.allowedNumbers(for: query).contains(99))
    }
}

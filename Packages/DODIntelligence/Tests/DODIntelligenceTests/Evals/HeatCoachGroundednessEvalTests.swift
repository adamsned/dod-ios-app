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

    @Test func groundedAnswerPasses() {
        let query = HeatCoachQuery(
            ovenDiameterInches: 12,
            style: .even,
            answer: "Start with 24 coals: 12 on the lid, 12 underneath, for about 350 degrees."
        )
        #expect(HeatCoachGroundednessEval.grade(query).isEmpty)
    }

    @Test func bakingSplitIsGrounded() {
        let query = HeatCoachQuery(
            ovenDiameterInches: 12,
            style: .baking,
            answer: "Use 24 coals: 18 on the lid and 6 on the bottom."
        )
        #expect(HeatCoachGroundednessEval.grade(query).isEmpty)
    }

    @Test func hallucinatedCoalCountFails() {
        let query = HeatCoachQuery(ovenDiameterInches: 12, style: .even, answer: "Use 40 coals")
        let failures = HeatCoachGroundednessEval.grade(query)
        #expect(failures.contains { $0.contains("ungrounded number") })
    }
}

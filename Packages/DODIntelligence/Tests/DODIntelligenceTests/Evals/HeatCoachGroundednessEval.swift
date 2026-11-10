import DODSupport
import Foundation

struct HeatCoachQuery: Sendable {
    let ovenDiameterInches: Int
    let style: CookingStyle
    /// The model's answer text under test.
    let answer: String
}

enum HeatCoachGroundednessEval {

    /// Numbers the answer may legitimately cite: the oven diameter and the grounded split.
    static func allowedNumbers(for query: HeatCoachQuery) -> Set<Int> {
        let split = DutchOvenHeatCoach.startingCoals(
            ovenDiameterInches: query.ovenDiameterInches,
            style: query.style
        )
        return [query.ovenDiameterInches, split.lid, split.bottom, split.total, 350]
    }
}

import DODSupport
import Foundation

struct HeatCoachQuery: Sendable {
    let ovenDiameterInches: Int
    let style: CookingStyle
    /// The model's answer text under test.
    let answer: String
}

import Foundation

/// Grounded, deterministic numbers for a Heat Coach follow-up question (DUT-1007).
/// Every figure comes from `DutchOvenHeatCoach`; nothing is LLM-generated.
public struct HeatCoachGroundedFacts: Equatable, Sendable {
    public let baseline: CoalSplit
    public let ambientDelta: ClosedRange<Int>
    public let windDelta: ClosedRange<Int>
    public let elevationCoalDelta: Int
    public let cookTimeExtraMinutes: ClosedRange<Int>
    public let replenishMinutes: Int
    /// Total coals after applying every adjustment: low and high ends of the range.
    public let adjustedTotal: ClosedRange<Int>

    /// One plain-text block the model can quote verbatim.
    public var summary: String {
        "Baseline \(baseline.total) coals (\(baseline.lid) lid / \(baseline.bottom) bottom). "
            + "Adjusted total \(adjustedTotal.lowerBound)-\(adjustedTotal.upperBound) coals. "
            + "Extra cook time \(cookTimeExtraMinutes.lowerBound)-\(cookTimeExtraMinutes.upperBound) min. "
            + "Add fresh coals every \(replenishMinutes) min."
    }
}

extension DutchOvenHeatCoach {
    public static func groundedFacts(
        ovenDiameterInches: Int,
        style: CookingStyle,
        ambient: AmbientCondition,
        windy: Bool,
        elevationFeet: Int
    ) -> HeatCoachGroundedFacts {
        let baseline = startingCoals(ovenDiameterInches: ovenDiameterInches, style: style)
        let amb = ambientCoalDelta(ambient)
        let wind = windCoalDelta(windy)
        let elev = elevationCoalDelta(elevationFeetAboveBaseline: elevationFeet)
        let low = max(0, baseline.total + amb.lowerBound + wind.lowerBound + elev)
        let high = max(0, baseline.total + amb.upperBound + wind.upperBound + elev)
        return HeatCoachGroundedFacts(
            baseline: baseline,
            ambientDelta: amb,
            windDelta: wind,
            elevationCoalDelta: elev,
            cookTimeExtraMinutes: cookTimeExtraMinutes(elevationFeetAboveBaseline: elevationFeet),
            replenishMinutes: replenishMinutes(ambient: ambient, windy: windy),
            adjustedTotal: low...high
        )
    }
}

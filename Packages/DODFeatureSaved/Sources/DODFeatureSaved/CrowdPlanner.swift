import DODDomain
import Foundation
import Observation

/// Headcount + budget state for the Make Shopping List sheet (DUT-997).
@Observable
@MainActor
public final class CrowdPlanner {
    public var headcount: Int = 4 {
        didSet { if headcount < 1 { headcount = 1 } }
    }
    public var recipes: [Recipe] = []

    public init(headcount: Int = 4) { self.headcount = max(headcount, 1) }

    public var estimate: CrowdBudgetEstimator.Estimate {
        CrowdBudgetEstimator.estimate(recipes: recipes, headcount: headcount)
    }

    /// Tips across all selected recipes, de-duplicated by text, in order.
    public var tips: [StretchTips.Tip] {
        var seen = Set<String>()
        return recipes.flatMap { StretchTips.tips(for: $0, headcount: headcount) }
            .filter { seen.insert($0.text).inserted }
    }

    /// e.g. "About $12.50 total · $1.56 per person".
    public var summaryText: String {
        guard !recipes.isEmpty else { return "" }
        let result = estimate
        return "About \(Self.money(result.totalCost)) total · \(Self.money(result.perPersonCost)) per person"
    }

    nonisolated static func money(_ value: Double) -> String {
        "$" + String(format: "%.2f", value)
    }
}

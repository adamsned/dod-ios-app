import Foundation

/// DUT-177 — the numbers behind a Cooking Wrapped recap. Pure + on-device.
public struct CookingWrapped: Equatable, Sendable {
    public let totalCooks: Int
    public let mostCooked: CookLogStats.RecipeFrequency?
    public let topCategory: String?
    /// Distinct recipes cooked in the period that had NO cook before the period started.
    public let newRecipesTried: Int
    public let busiestMonth: CookLogStats.MonthFrequency?

    public static func make(
        entries: [CookLogEntry],
        period: CookingWrappedPeriod,
        categoryByRecipeID: [Int: String],
        calendar: Calendar = .current
    ) -> CookingWrapped {
        let inPeriod = period.filter(entries, calendar: calendar)
        var priorIDs = Set<Int>()
        if let start = period.range(calendar: calendar)?.start {
            priorIDs = Set(entries.filter { $0.cookedAt < start }.map(\.recipeID))
        }
        let newIDs = Set(inPeriod.map(\.recipeID)).subtracting(priorIDs)

        var categoryCounts: [String: Int] = [:]
        for entry in inPeriod {
            if let name = categoryByRecipeID[entry.recipeID] { categoryCounts[name, default: 0] += 1 }
        }
        // Most cooks wins; ties break alphabetically for determinism.
        let topCategory = categoryCounts.max { left, right in
            left.value != right.value ? left.value > right.value : left.key < right.key
        }?.key

        return CookingWrapped(
            totalCooks: inPeriod.count,
            mostCooked: CookLogStats.mostCooked(inPeriod),
            topCategory: topCategory,
            newRecipesTried: newIDs.count,
            busiestMonth: CookLogStats.busiestMonth(inPeriod, calendar: calendar)
        )
    }
}

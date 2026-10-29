import DODSupport
import Foundation

public struct TripFuelLedger: Sendable, Equatable {
    /// Briquettes needed per day (index 0 = day 1), summed from slot charcoal totals.
    public let briquettesPerDay: [Int]
    public let totalBriquettes: Int
    /// Bags needed, rounded UP. Default bag size is 40 briquettes (a common bag; make it a param).
    public let bags: Int

    public init(plan: TripPlan, days: Int, briquettesPerBag: Int = 40) {
        var perDay = Array(repeating: 0, count: max(1, days))
        for slot in plan.slots {
            let dayIndex = min(max(0, slot.day - 1), perDay.count - 1)
            perDay[dayIndex] += slot.charcoal?.totalBriquettes ?? 0
        }
        self.briquettesPerDay = perDay
        self.totalBriquettes = perDay.reduce(0, +)
        let size = max(1, briquettesPerBag)
        self.bags = (totalBriquettes + size - 1) / size
    }
}

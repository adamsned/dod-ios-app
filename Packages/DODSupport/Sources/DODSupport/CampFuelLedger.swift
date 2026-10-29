import Foundation

/// DUT-1000 — simple fuel-remaining ledger. Tracks briquettes packed and
/// briquettes burned per meal.
public struct CampFuelLedger: Sendable, Equatable, Codable {
    public var packedBriquettes: Int
    /// mealID -> briquettes actually used.
    public private(set) var used: [UUID: Int] = [:]

    public init(packedBriquettes: Int) { self.packedBriquettes = max(0, packedBriquettes) }

    /// Start a ledger packed with the full planned budget.
    public init(budget: CampFuelBudget.Budget) { self.init(packedBriquettes: budget.totalBriquettes) }

    public mutating func recordUsed(_ briquettes: Int, for mealID: UUID) {
        used[mealID] = max(0, briquettes)  // re-recording replaces, never double-counts
    }

    public var totalUsed: Int { used.values.reduce(0, +) }

    /// May go negative (ran short) so the UI can warn.
    public var remaining: Int { packedBriquettes - totalUsed }

    /// True when the planned briquettes for the not-yet-cooked meals exceed what is left.
    public func isShort(for budget: CampFuelBudget.Budget) -> Bool {
        let pending = budget.perMeal.filter { used[$0.mealID] == nil }.reduce(0) { $0 + $1.briquettes }
        return pending > 0 && pending > remaining  // nothing left to cook means nothing to be short for
    }
}

import Foundation

/// DUT-965 — turns a `CookoutPlan` into a start-time schedule and coal budget.
public enum CookoutScheduler {
    public struct Entry: Sendable, Equatable, Identifiable {
        public let recipeID: Int
        public let title: String
        public let startAt: Date
        public let coals: CoalSplit
        public var id: Int { recipeID }
    }

    /// Each dish starts `cookMinutes` before `plan.serveAt`, sorted by earliest start first.
    /// Ties break by title so the order is deterministic.
    public static func schedule(for plan: CookoutPlan) -> [Entry] {
        plan.dishes.map { dish in
            Entry(
                recipeID: dish.recipeID,
                title: dish.title,
                startAt: plan.serveAt.addingTimeInterval(-Double(dish.cookMinutes) * 60),
                coals: DutchOvenHeatCoach.startingCoals(
                    ovenDiameterInches: dish.ovenDiameterInches,
                    style: dish.isBaking ? .baking : .even
                )
            )
        }
        .sorted { ($0.startAt, $0.title) < ($1.startAt, $1.title) }
    }

    /// Total starting coals across every dish (the shopping number for charcoal).
    public static func totalCoals(for plan: CookoutPlan) -> Int {
        schedule(for: plan).reduce(0) { $0 + $1.coals.total }
    }
}

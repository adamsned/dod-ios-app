import Foundation

/// DUT-980: one dish to land at the serve moment.
public struct ServingDish: Sendable, Hashable, Identifiable {
    public let id: Int  // Recipe.id
    public let title: String
    public let prepSeconds: Int
    public let cookSeconds: Int

    public init(id: Int, title: String, prepSeconds: Int, cookSeconds: Int) {
        self.id = id
        self.title = title
        self.prepSeconds = max(prepSeconds, 0)
        self.cookSeconds = max(cookSeconds, 0)
    }

    public init(recipe: Recipe) {
        func secs(_ duration: Duration?) -> Int {
            Int((duration ?? .zero).components.seconds)
        }
        self.init(
            id: recipe.id,
            title: recipe.title,
            prepSeconds: secs(recipe.prepTime),
            cookSeconds: secs(recipe.cookTime)
        )
    }
}

/// Staggered times for one dish. `cookStart` = when coals/heat go on; `prepStart` = when prep begins.
public struct ServingScheduleEntry: Sendable, Hashable, Identifiable {
    public let dishID: Int
    public let title: String
    public let prepStart: Date
    public let cookStart: Date
    public let serveAt: Date
    public var id: Int { dishID }

    public init(dishID: Int, title: String, prepStart: Date, cookStart: Date, serveAt: Date) {
        self.dishID = dishID
        self.title = title
        self.prepStart = prepStart
        self.cookStart = cookStart
        self.serveAt = serveAt
    }
}

public enum ServingPlanner {
    /// Backward schedule: every entry ends at `serveAt`. Sorted by `prepStart`
    /// ascending (longest dish first); ties break on dishID.
    public static func plan(dishes: [ServingDish], serveAt: Date) -> [ServingScheduleEntry] {
        dishes.map { dish in
            let cookStart = serveAt.addingTimeInterval(-TimeInterval(dish.cookSeconds))
            let prepStart = cookStart.addingTimeInterval(-TimeInterval(dish.prepSeconds))
            return ServingScheduleEntry(
                dishID: dish.id,
                title: dish.title,
                prepStart: prepStart,
                cookStart: cookStart,
                serveAt: serveAt
            )
        }
        .sorted { ($0.prepStart, $0.dishID) < ($1.prepStart, $1.dishID) }
    }

    /// Earliest moment the cook must begin; nil for no dishes.
    public static func earliestStart(of plan: [ServingScheduleEntry]) -> Date? {
        plan.map(\.prepStart).min()
    }
}

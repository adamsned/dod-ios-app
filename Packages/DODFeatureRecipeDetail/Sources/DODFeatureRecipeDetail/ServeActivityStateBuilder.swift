import DODCookActivity
import DODDomain
import Foundation

/// DUT-980: pure mapping from a backward `ServingPlanner` plan to the unified Live Activity payload.
public enum ServeActivityStateBuilder {
    public static func attributes(title: String = "Dinner is served") -> ServeActivityAttributes {
        ServeActivityAttributes(title: title)
    }

    public static func state(
        from plan: [ServingScheduleEntry],
        serveAt: Date
    ) -> ServeActivityAttributes.ContentState {
        let dishes = plan.map {
            ServeActivityAttributes.Dish(
                id: $0.dishID,
                title: $0.title,
                cookStart: $0.cookStart,
                serveAt: $0.serveAt
            )
        }
        return .init(dishes: dishes, serveAt: serveAt)
    }

    /// State to push once the serve moment has passed.
    public static func completed(
        _ state: ServeActivityAttributes.ContentState
    ) -> ServeActivityAttributes.ContentState {
        var copy = state
        copy.isCompleted = true
        return copy
    }
}

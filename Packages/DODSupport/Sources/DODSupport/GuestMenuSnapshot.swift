import Foundation

/// DUT-965 — what guests see: "Chef is making…" with a live status per dish.
public struct GuestMenuSnapshot: Sendable, Equatable {
    public enum Status: String, Sendable, Equatable {
        case upNext  // start time is in the future
        case cooking  // started, serve time not yet reached
        case ready  // serve time reached
    }

    public struct Item: Sendable, Equatable, Identifiable {
        public let recipeID: Int
        public let title: String
        public let status: Status
        public var id: Int { recipeID }
    }

    public let planName: String
    public let guestCount: Int
    public let serveAt: Date
    public let items: [Item]

    /// Statuses are computed against the injected `now` (no wall-clock access, so it is testable).
    public static func make(from plan: CookoutPlan, now: Date) -> GuestMenuSnapshot {
        let items = CookoutScheduler.schedule(for: plan).map { entry -> Item in
            let status: Status
            if now >= plan.serveAt {
                status = .ready
            } else if now >= entry.startAt {
                status = .cooking
            } else {
                status = .upNext
            }
            return Item(recipeID: entry.recipeID, title: entry.title, status: status)
        }
        return GuestMenuSnapshot(
            planName: plan.name,
            guestCount: plan.guestCount,
            serveAt: plan.serveAt,
            items: items
        )
    }
}

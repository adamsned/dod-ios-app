import Foundation

#if os(iOS)
import ActivityKit
#endif

/// DUT-980: ONE Live Activity listing every dish counting down to a single serve moment.
public struct ServeActivityAttributes: Codable, Hashable, Sendable {

    public struct Dish: Codable, Hashable, Sendable, Identifiable {
        /// Recipe id.
        public var id: Int
        public var title: String
        /// When heat/coals go on.
        public var cookStart: Date
        public var serveAt: Date

        public init(id: Int, title: String, cookStart: Date, serveAt: Date) {
            self.id = id
            self.title = title
            self.cookStart = cookStart
            self.serveAt = serveAt
        }
    }

    public struct ContentState: Codable, Hashable, Sendable {
        public var dishes: [Dish]
        public var serveAt: Date
        public var isCompleted: Bool

        public init(dishes: [Dish], serveAt: Date, isCompleted: Bool = false) {
            self.dishes = dishes
            self.serveAt = serveAt
            self.isCompleted = isCompleted
        }

        /// Dishes whose cookStart is still in the future at `now` (not yet on the heat).
        public func upcoming(at now: Date) -> [Dish] {
            dishes.filter { $0.cookStart > now }
        }

        /// Dishes already cooking at `now`.
        public func cooking(at now: Date) -> [Dish] {
            dishes.filter { $0.cookStart <= now }
        }
    }

    /// e.g. "Dinner is served".
    public var title: String

    public init(title: String) {
        self.title = title
    }
}

#if os(iOS)
@available(iOS 16.1, *)
extension ServeActivityAttributes: ActivityAttributes {}
#endif

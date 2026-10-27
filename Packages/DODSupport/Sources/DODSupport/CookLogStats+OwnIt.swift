import Foundation

extension CookLogStats {

    /// DUT-974 — cooks of one recipe needed before it counts as "owned".
    public static let ownItThreshold = 3

    /// A recipe's progress toward being "owned" (cooked `ownItThreshold` times).
    public struct OwnItProgress: Equatable, Sendable {
        public let recipeID: Int
        public let title: String
        public let timesCooked: Int
        public let remaining: Int  // 0 once owned
        public var isOwned: Bool { remaining == 0 }
    }

    /// Progress for one recipe. Nil when it has never been cooked.
    public static func ownItProgress(recipeID: Int, in entries: [CookLogEntry]) -> OwnItProgress? {
        let count = timesCooked(recipeID: recipeID, in: entries)
        guard count > 0 else { return nil }
        // Title from the most recent cook of this recipe.
        let title =
            entries.filter { $0.recipeID == recipeID }
            .max { $0.cookedAt < $1.cookedAt }?.recipeTitle ?? ""
        return OwnItProgress(
            recipeID: recipeID,
            title: title,
            timesCooked: count,
            remaining: max(0, ownItThreshold - count)
        )
    }
}

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

    /// DUT-974 — gateway dishes in progress (cooked, not yet owned), closest to
    /// owned first. Ties: most recently cooked, then lower recipe id.
    public static func onYourWayToOwning(_ entries: [CookLogEntry], limit: Int = 3) -> [OwnItProgress] {
        let ids = Set(entries.map(\.recipeID))
        let lastCooked: [Int: Date] = Dictionary(grouping: entries, by: \.recipeID)
            .mapValues { $0.map(\.cookedAt).max() ?? .distantPast }
        let inProgress = ids.compactMap { ownItProgress(recipeID: $0, in: entries) }
            .filter { !$0.isOwned }
        let sorted = inProgress.sorted { lhs, rhs in
            if lhs.remaining != rhs.remaining { return lhs.remaining < rhs.remaining }
            let lhsDate = lastCooked[lhs.recipeID] ?? .distantPast
            let rhsDate = lastCooked[rhs.recipeID] ?? .distantPast
            if lhsDate != rhsDate { return lhsDate > rhsDate }
            return lhs.recipeID < rhs.recipeID
        }
        return Array(sorted.prefix(max(0, limit)))
    }
}

import Foundation

/// DUT-964: where the cook stands on the hero's path, derived purely from the
/// recipe ids in their journal.
public struct PathProgress: Equatable, Sendable {
    /// Rungs in ``GuidedCookout/path`` the cook has actually cooked (any order).
    public let cookedRungs: Int
    public let totalRungs: Int
    /// The recommended next rung; nil for a path graduate.
    public let nextRung: GuidedCookout?

    public var isGraduate: Bool { nextRung == nil }
    /// 0...1 fraction of the ladder climbed.
    public var fraction: Double {
        totalRungs == 0 ? 0 : Double(cookedRungs) / Double(totalRungs)
    }
}

extension GuidedCookout {
    public static func pathProgress(cookedRecipeIDs: Set<Int>) -> PathProgress {
        PathProgress(
            cookedRungs: path.filter { cookedRecipeIDs.contains($0.recipeID) }.count,
            totalRungs: path.count,
            nextRung: nextUncookedRung(cookedRecipeIDs: cookedRecipeIDs)
        )
    }
}

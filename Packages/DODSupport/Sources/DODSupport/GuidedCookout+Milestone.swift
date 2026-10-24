import Foundation

/// DUT-964: a ladder beat triggered by a logged cook.
public enum RungMilestone: Equatable, Sendable {
    /// A new home rung was cooked; `next` is the recommended rung now.
    case rungCleared(cleared: GuidedCookout, next: GuidedCookout)
    /// The campfire just unlocked (first home rung cooked).
    case campfireUnlocked
    /// Every rung is now cooked (a path graduate).
    case graduated
}

extension GuidedCookout {
    /// The milestone newly reached going from `before` to `after`, or nil.
    /// Priority: graduated > campfireUnlocked > rungCleared.
    public static func milestone(
        from before: Set<Int>,
        to after: Set<Int>
    ) -> RungMilestone? {
        let wasGrad = nextUncookedRung(cookedRecipeIDs: before) == nil
        let isGrad = nextUncookedRung(cookedRecipeIDs: after) == nil
        if isGrad && !wasGrad { return .graduated }
        if isCampfireLocked(cookedRecipeIDs: before), !isCampfireLocked(cookedRecipeIDs: after) {
            return .campfireUnlocked
        }
        let newlyCooked = path.first {
            after.contains($0.recipeID) && !before.contains($0.recipeID)
        }
        guard let cleared = newlyCooked,
            let next = nextUncookedRung(cookedRecipeIDs: after)
        else { return nil }
        return .rungCleared(cleared: cleared, next: next)
    }
}

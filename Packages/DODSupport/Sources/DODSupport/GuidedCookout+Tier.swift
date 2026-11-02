import Foundation

extension GuidedCookout {

    /// DUT-964: the ladder's two phases.
    public enum Tier: String, Sendable, Equatable {
        /// Weeknight reps at home: the retention engine.
        case home
        /// The witnessed outdoor peak.
        case outdoor
    }

    public var tier: Tier { isCampfire ? .outdoor : .home }

    /// One-line reassurance on why this rung is low-risk, shown under the dish.
    public var forgivingNote: String {
        if isCampfire { return "Same dish you already know. Only the setting is new." }
        if isFirstRung { return "Layered and hard to ruin. Forgiving on timing." }
        return "A dump and braise. Hard to overcook."
    }
}

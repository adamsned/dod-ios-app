import Foundation

/// DUT-1002 — where a recipe step happens in a split cook.
public enum CookStage: String, Sendable, Hashable, Codable, CaseIterable {
    /// Day-before / at-home prep.
    case kitchenPrep
    /// Finished at the campsite over coals.
    case campfireFinish
}

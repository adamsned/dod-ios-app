import Foundation

/// DUT-1021 — decides whether Cook Mode still offers "Explain this step".
public enum StepExplanationOfferPolicy {
    /// Number of explanations a cook may request before we consider them levelled up.
    public static let dismissThreshold = 10

    /// - Parameters:
    ///   - explainCount: how many times this user has used the explain button.
    ///   - hasLevelledUp: `true` once the user has earned the relevant technique milestone (DUT-973).
    public static func shouldOffer(explainCount: Int, hasLevelledUp: Bool) -> Bool {
        !hasLevelledUp && explainCount < dismissThreshold
    }
}

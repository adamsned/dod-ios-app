import Foundation

extension LiveDODIntelligenceService {
    static let donenessInstructions = """
        You are a calm cast-iron cooking coach. Look at the photo and the recipe step and say whether the \
        food LOOKS done for that step (browning, bubbling, rise, char). Judge only what is visible. \
        NEVER state or imply a temperature, internal doneness, or food safety; for meat that is the \
        thermometer's job. If the photo is unclear, say unsure with low confidence.
        """

    static func donenessPrompt(stepText: String) -> String {
        "Current recipe step: \(String(stepText.prefix(1000)))\nDoes the food in the photo look done for this step?"
    }

    /// Map the model's strings onto the plain result; unknown verdict becomes .unsure.
    static func mapDoneness(verdict: String, confidence: Double, reassurance: String) -> DonenessCheckResult? {
        let text = reassurance.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = verdict.lowercased()
        let mapped: DonenessCheckResult.Verdict =
            lower.contains("notyet") || lower.contains("not yet")
            ? .notYet
            : lower.contains("done") ? .looksDone : .unsure
        return DonenessCheckResult(verdict: mapped, confidence: confidence, reassurance: text)
    }
}

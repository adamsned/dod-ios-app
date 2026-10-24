import Foundation

/// What the on-device model concluded from the photo. VISUAL doneness only.
public struct DonenessCheckResult: Sendable, Equatable {
    public enum Verdict: String, Sendable, Equatable {
        case looksDone, notYet, unsure
    }
    public let verdict: Verdict
    /// 0...1, clamped in init.
    public let confidence: Double
    /// One or two calm sentences about what is visible (colour, bubbling, rise, char).
    public let reassurance: String

    /// Below this confidence the verdict is downgraded to `.unsure`.
    public static let confidenceThreshold = 0.6

    public init(verdict: Verdict, confidence: Double, reassurance: String) {
        let clamped = min(max(confidence, 0), 1)
        self.confidence = clamped
        self.verdict = clamped < Self.confidenceThreshold ? .unsure : verdict

        // If the reassurance contains a safety claim or if we're unsure and reassurance is empty,
        // use the unsure note instead
        if Self.containsSafetyClaim(reassurance) || (self.verdict == .unsure && reassurance.isEmpty) {
            self.reassurance = Self.unsureNote
        } else {
            self.reassurance = reassurance
        }
    }

    /// Safe fallback line when the model is not confident.
    public static let unsureNote = "I can't tell from this photo. Try better light, or a closer shot of the crust."

    /// True when the text makes a temperature or food-safety claim, which this coach must never make.
    public static func containsSafetyClaim(_ text: String) -> Bool {
        let lower = text.lowercased()
        return ["°", "degrees", "internal temp", "safe to eat", "cooked through", "thermometer"].contains {
            lower.contains($0)
        }
    }
}

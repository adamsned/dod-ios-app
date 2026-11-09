import DODDomain
import Foundation

/// DUT-1029 — deterministic spoken answers for hands-free Cook Mode.
public enum CookModeSpokenAnswers {

    /// What to say for "what's next": the step after the current one, or a closing line.
    public static func whatsNext(steps: [RecipeInstruction], currentStepIndex: Int) -> String {
        let nextIndex = currentStepIndex + 1
        guard nextIndex >= 0, nextIndex < steps.count else {
            return "That's the last step."
        }
        return "Next: \(steps[nextIndex].text)"
    }
}

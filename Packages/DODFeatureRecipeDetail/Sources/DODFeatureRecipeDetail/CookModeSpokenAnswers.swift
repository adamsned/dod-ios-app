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

    /// Deterministic answer for "how much / how many X" using the recipe's own ingredient lines.
    /// Returns nil when the question is not a quantity question or no line matches.
    public static func ingredientAnswer(question: String, ingredientLines: [String]) -> String? {
        let lower = question.lowercased()
        guard lower.contains("how much") || lower.contains("how many") else { return nil }
        let stop: Set<String> = [
            "how", "much", "many", "the", "need", "does", "this", "recipe", "use", "for", "are", "there",
        ]
        let words = lower.components(separatedBy: CharacterSet.letters.inverted)
            .filter { $0.count > 2 && !stop.contains($0) }
        let match = ingredientLines.first { line in
            let text = line.lowercased()
            return words.contains { text.contains($0) }
        }
        guard let match else { return nil }
        return "The recipe lists \(match)."
    }
}

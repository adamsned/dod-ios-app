import Foundation

#if os(iOS)
import FoundationModels
#endif

extension LiveDODIntelligenceService {

    /// Pure prompt builder, non-FoundationModels so it is testable on macOS.
    static func explainStepPrompt(step: String, nextStep: String?) -> String {
        var lines = ["Step to explain: \(String(step.prefix(1200)))"]
        if let nextStep, !nextStep.isEmpty { lines.append("Next step (context only): \(String(nextStep.prefix(600)))") }
        return lines.joined(separator: "\n")
    }

    static let explainStepInstructions = """
        You help a nervous beginner cook understand ONE recipe step. Rephrase it in plain, \
        reassuring words, say why it matters, and name one common mistake. \
        Use ONLY facts in the step text. NEVER add a temperature, time, quantity or ingredient \
        that is not written in the step. If the step gives no number, give no number.
        """

    #if os(iOS)
    @available(iOS 26, *)
    static func generateStepExplanation(step: String, nextStep: String?) async -> StepExplanation? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }
        let session = LanguageModelSession(instructions: explainStepInstructions)
        do {
            let reply = try await session.respond(
                to: explainStepPrompt(step: step, nextStep: nextStep),
                generating: GenerableStepExplanation.self
            )
            let value = StepExplanation(
                expandedText: reply.content.expandedText.trimmingCharacters(in: .whitespacesAndNewlines),
                whyItMatters: reply.content.whyItMatters.trimmingCharacters(in: .whitespacesAndNewlines),
                commonMistake: reply.content.commonMistake.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            guard !value.expandedText.isEmpty, value.isGrounded(in: step) else { return nil }
            return value
        } catch {
            return nil
        }
    }

    @available(iOS 26, *)
    @Generable
    struct GenerableStepExplanation {
        @Guide(description: "The step rephrased simply for a beginner, at most two short sentences. No new numbers.")
        var expandedText: String
        @Guide(description: "One short sentence on why this step matters.")
        var whyItMatters: String
        @Guide(description: "One short sentence on the most common beginner mistake. No new numbers.")
        var commonMistake: String
    }
    #endif
}

import Foundation

#if os(iOS)
import FoundationModels
#endif

extension LiveDODIntelligenceService {

    static let askRecipeInstructions = """
        You answer questions about ONE recipe. Always call tools for ingredients, steps and quantities. \
        Never invent or calculate quantities yourself. If the tools do not say, say the recipe does not \
        specify and give brief general advice.
        """

    public func askRecipe(_ question: String, toolbox: AskRecipeToolbox) async -> String? {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        #if os(iOS)
        if #available(iOS 26, *) {
            return await Self.generateRecipeAnswer(question: trimmed, toolbox: toolbox)
        }
        return nil
        #else
        return nil
        #endif
    }

    #if os(iOS)
    @available(iOS 26, *)
    static func generateRecipeAnswer(question: String, toolbox: AskRecipeToolbox) async -> String? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }
        let session = LanguageModelSession(
            tools: [
                RecipeIngredientsTool(toolbox: toolbox),
                RecipeStepsTool(toolbox: toolbox),
                RecipeMakeAheadTool(toolbox: toolbox),
            ],
            instructions: askRecipeInstructions
        )
        do {
            let reply = try await session.respond(
                to: question,
                generating: GenerableRecipeAnswer.self,
                options: askRecipeOptions()
            )
            let answer = reply.content.answer.trimmingCharacters(in: .whitespacesAndNewlines)
            return answer.isEmpty ? nil : answer
        } catch {
            return nil
        }
    }

    /// Default generation options; a future iOS 27 tool-calling mode can be set here.
    @available(iOS 26, *)
    private static func askRecipeOptions() -> GenerationOptions {
        GenerationOptions()
    }

    @available(iOS 26, *)
    @Generable
    struct GenerableRecipeAnswer {
        @Guide(
            description:
                "One to three short sentences, on-topic, using only tool results for quantities. Do not use em dashes."
        )
        var answer: String
    }
    #endif
}

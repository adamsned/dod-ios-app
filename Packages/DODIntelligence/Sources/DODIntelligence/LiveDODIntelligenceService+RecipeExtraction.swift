#if os(iOS)
import FoundationModels

@available(iOS 26, *)
@Generable
private struct GeneratedRecipeLists {
    @Guide(description: "Ingredient lines exactly as written in the text")
    var ingredients: [String]
    @Guide(description: "Instruction steps exactly as written, in order")
    var instructions: [String]
}

extension LiveDODIntelligenceService {
    static let extractionInstructions = """
        You copy a recipe out of web page text. List ONLY ingredients and steps that \
        appear verbatim in the text. Never invent, infer or add anything. If the text \
        has no recipe, return empty lists.
        """

    static func extractionPrompt(chunk: String) -> String {
        "Recipe page text:\n\n\(chunk)"
    }

    /// Drop any line the model returned that is not grounded in the source text
    /// (hallucination guard): keep a line only if its lowercase, whitespace-collapsed
    /// form is contained in the lowercase, whitespace-collapsed body.
    static func grounded(_ result: ExtractedRecipe, in body: String) -> ExtractedRecipe {
        func norm(_ string: String) -> String {
            string.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
        }
        let haystack = norm(body)
        return ExtractedRecipe(
            ingredients: result.ingredients.filter { haystack.contains(norm($0)) },
            instructions: result.instructions.filter { haystack.contains(norm($0)) }
        )
    }

    @available(iOS 26, *)
    static func generateExtraction(chunk: String) async -> ExtractedRecipe? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }
        let session = LanguageModelSession(instructions: extractionInstructions)
        do {
            let response = try await session.respond(
                to: extractionPrompt(chunk: chunk),
                generating: GeneratedRecipeLists.self
            )
            return ExtractedRecipe(
                ingredients: response.content.ingredients,
                instructions: response.content.instructions
            )
        } catch { return nil }
    }

    @available(iOS 26, *)
    public static func extractRecipe(fromBody body: String) async -> ExtractedRecipe? {
        guard #available(iOS 26, *),
            !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            case .available = SystemLanguageModel.default.availability
        else { return nil }

        let chunks = RecipeTextChunker.chunks(of: body)
        var results: [ExtractedRecipe] = []

        for chunk in chunks {
            if let result = await generateExtraction(chunk: chunk) {
                results.append(result)
            }
        }

        guard !results.isEmpty else { return nil }

        let merged = ExtractedRecipe.merged(results)
        let groundedResult = grounded(merged, in: body)

        return groundedResult.isEmpty ? nil : groundedResult
    }
}
#endif

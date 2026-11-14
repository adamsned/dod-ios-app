import DODSupport
import Foundation

#if os(iOS)
import FoundationModels
#endif

// On-device guided generation for one ingredient line (DUT-1020 / DUT-1806).
// iOS-26-only: everything model-related is inside `#if os(iOS)` + `@available(iOS 26, *)`.
extension LiveDODIntelligenceService {

    #if os(iOS)
    /// FoundationModels-native mirror of `IngredientParse`; mapped onto the plain
    /// type before returning so the framework never escapes this unit.
    @available(iOS 26, *)
    @Generable
    struct GenerableIngredientParse {
        @Guide(description: "Numeric amount exactly as written, e.g. 1.5 for '1 1/2'. Omit if the line has no number.")
        var quantity: Double?
        @Guide(description: "Unit as written, e.g. cup, tbsp, clove. Omit if none.")
        var unit: String?
        @Guide(description: "The ingredient itself without amount or preparation, e.g. 'yellow onion'.")
        var item: String
        @Guide(description: "Preparation notes such as 'finely chopped' or 'to taste'. Omit if none.")
        var prep: String?
    }

    /// System instructions for the single-line ingredient parse. The `@Generable`
    /// schema carries the field contract; this carries the judgement.
    @available(iOS 26, *)
    static let ingredientParseInstructions = """
        Split one recipe ingredient line into quantity, unit, item and prep. \
        Copy numbers exactly as written; convert fractions to decimals. \
        Never guess a quantity: if the line has no number (e.g. "salt to taste"), \
        leave quantity empty. Do not convert units.
        """

    /// The single place that touches the model for ingredient parsing. Any error,
    /// including a guardrail rejection, degrades to `nil`. The result is NOT trusted
    /// directly: callers pass it through `IngredientParseGate.resolve`.
    @available(iOS 26, *)
    static func generateIngredientParse(_ line: String) async -> IngredientParse? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }
        let session = LanguageModelSession(instructions: ingredientParseInstructions)
        do {
            let reply = try await session.respond(
                to: line,
                generating: GenerableIngredientParse.self
            )
            let content = reply.content
            let item = content.item.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !item.isEmpty else { return nil }
            return IngredientParse(
                quantity: content.quantity,
                unit: content.unit,
                item: item,
                prep: content.prep
            )
        } catch {
            return nil
        }
    }
    #endif
}

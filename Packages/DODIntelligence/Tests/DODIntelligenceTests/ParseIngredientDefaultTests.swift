import DODDomain
import DODSupport
import Foundation
import Testing

@testable import DODIntelligence

/// DUT-1020 — a conformer that predates `parseIngredient` must get the `nil`
/// default so callers fall back to the heuristic `IngredientLineParser`.
@Suite("DODIntelligence parseIngredient default")
struct ParseIngredientDefaultTests {

    private struct NoParse: DODIntelligenceService {
        var isAvailable: Bool { true }
        var supportsImageInput: Bool { false }
        func suggestSubstitution(
            for ingredient: String,
            in context: RecipeContext?,
            reason: SubstitutionReason?
        ) async -> SubstitutionResult? { nil }
        func summarize(_ text: String) async -> String? { nil }
        func answer(_ question: String, imageData: Data?, recipeContext: String?) async -> String? { nil }
    }

    @Test func defaultParseIngredientReturnsNil() async {
        let svc = NoParse()
        let parse = await svc.parseIngredient("2 cups flour")
        #expect(parse == nil)
    }
}

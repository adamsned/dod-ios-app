import DODDomain
import DODFeatureSaved
import DODIntelligence
import DODSupport
import Foundation
import Testing

struct AisleStubService: DODIntelligenceService {
    let isAvailable: Bool = true
    let supportsImageInput: Bool = false

    func suggestSubstitution(
        for ingredient: String,
        in context: RecipeContext?,
        reason: SubstitutionReason?
    ) async -> SubstitutionResult? {
        nil
    }

    func summarize(_ text: String) async -> String? {
        nil
    }

    func answer(_ question: String, imageData: Data?, recipeContext: String?) async -> String? {
        nil
    }

    func checkDoneness(photo: Data, stepText: String) async -> DonenessCheckResult? {
        nil
    }

    func explainStep(_ step: String, nextStep: String?) async -> StepExplanation? {
        nil
    }

    func extractRecipe(fromBody body: String) async -> ExtractedRecipe? {
        nil
    }

    func classifyAisle(_ text: String) async -> IngredientAisleClassifier.Aisle? {
        if text.contains("gochujang") {
            return .pantry
        }
        return nil
    }
}

@MainActor
struct ShoppingListAisleRefinementTests {
    @Test func otherRowIsRefiledToPantry() async {
        let vm = ShoppingListViewModel(
            items: [.init(ingredientText: "1 tbsp gochujang", recipeTitle: "R", aisle: .other)],
            store: nil,
            intelligence: AisleStubService()
        )
        await vm.refineOtherAisles()
        #expect(vm.items.first?.aisle == .pantry)
    }

    @Test func keywordRowsAreNeverReclassified() async {
        let id = UUID()
        let vm = ShoppingListViewModel(
            items: [.init(id: id, ingredientText: "1 gochujang onion", recipeTitle: "R", aisle: .produce)],
            store: nil,
            intelligence: AisleStubService()
        )
        await vm.refineOtherAisles()
        #expect(vm.items.first?.aisle == .produce)
    }

    @Test func noServiceIsNoOp() async {
        let vm = ShoppingListViewModel(
            items: [.init(ingredientText: "x", recipeTitle: "R", aisle: .other)],
            store: nil
        )
        await vm.refineOtherAisles()
        #expect(vm.items.first?.aisle == .other)
    }
}

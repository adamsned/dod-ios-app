import DODDomain
import DODIntelligence
import Foundation
import Testing

@testable import DODFeatureSaved

/// L1 coverage for the v2 on-device-AI substitution seam on
/// ``ShoppingListViewModel`` — the availability flag, the pickingReason →
/// loading → loaded / notFound state machine, the three verdicts (options /
/// omit / not-a-good-fit), Apply / Leave-It-Out, and that recipe context is
/// passed to the model (constitution §6 L1 mandate).
///
/// The live model is unavailable in the simulator / CI and non-deterministic,
/// so these drive fakes — the seam, never the model.
@MainActor
@Suite("ShoppingListViewModel — substitution (v2 AI)")
struct ShoppingListViewModelSubstitutionTests {

    private static func item(_ text: String, recipe: String = "R") -> ShoppingListViewModel.Item {
        ShoppingListViewModel.Item(ingredientText: text, recipeTitle: recipe, aisle: .produce)
    }

    private static func model(
        items: [ShoppingListViewModel.Item] = [],
        isAvailable: Bool = true,
        substitution: SubstitutionResult? = .cannedButtermilkOptions
    ) -> ShoppingListViewModel {
        ShoppingListViewModel(
            items: items,
            store: nil,
            intelligence: FakeIntelligenceService(isAvailable: isAvailable, substitution: substitution)
        )
    }

    /// A fake that records the recipe context it was handed, for the
    /// recipe-aware wiring test.
    private final class CapturingIntelligence: DODIntelligenceService, @unchecked Sendable {
        let isAvailable = true
        let supportsImageInput = false
        private(set) var capturedContext: RecipeContext?
        private let result: SubstitutionResult?
        init(result: SubstitutionResult?) { self.result = result }
        func suggestSubstitution(
            for ingredient: String,
            in context: RecipeContext?,
            reason: SubstitutionReason?
        ) async -> SubstitutionResult? {
            capturedContext = context
            return result
        }
        func summarize(_ text: String) async -> String? { nil }
        func answer(_ question: String, imageData: Data?, recipeContext: String?) async -> String? { nil }
    }

    // MARK: - Availability gate

    @Test func affordanceHiddenWhenNoServiceInjected() {
        #expect(!ShoppingListViewModel(items: [], store: nil).isSubstitutionAvailable)
    }

    @Test func affordanceHiddenWhenServiceUnavailable() {
        #expect(!Self.model(isAvailable: false).isSubstitutionAvailable)
    }

    @Test func affordanceShownWhenServiceAvailable() {
        #expect(Self.model(isAvailable: true).isSubstitutionAvailable)
    }

    // MARK: - Flow

    @Test func beginOpensTheReasonPicker() {
        let target = Self.item("1 cup buttermilk")
        let viewModel = Self.model(items: [target])
        viewModel.beginSubstitution(for: target)
        #expect(viewModel.substitution == .pickingReason(itemID: target.id, ingredient: "1 cup buttermilk"))
    }

    @Test func beginIsNoOpWhenUnavailable() {
        let target = Self.item("1 cup buttermilk")
        let viewModel = Self.model(items: [target], isAvailable: false)
        viewModel.beginSubstitution(for: target)
        #expect(viewModel.substitution == .idle)
    }

    @Test func generateExposesCannedOptions() async {
        let target = Self.item("1 cup buttermilk")
        let viewModel = Self.model(items: [target], substitution: .cannedButtermilkOptions)
        viewModel.beginSubstitution(for: target)
        await viewModel.generateSubstitution(reason: .dairyFree)
        #expect(
            viewModel.substitution
                == .loaded(
                    itemID: target.id,
                    ingredient: "1 cup buttermilk",
                    reason: .dairyFree,
                    result: .cannedButtermilkOptions
                )
        )
    }

    @Test func generateWithNoResultLandsInNotFound() async {
        let target = Self.item("unobtanium")
        let viewModel = Self.model(items: [target], substitution: nil)
        viewModel.beginSubstitution(for: target)
        await viewModel.generateSubstitution(reason: nil)
        #expect(viewModel.substitution == .notFound(itemID: target.id, ingredient: "unobtanium"))
    }

    @Test func generatePassesRecipeContextWithSiblings() async {
        let target = Self.item("green beans", recipe: "Asian Green Beans")
        let sibling = Self.item("soy sauce", recipe: "Asian Green Beans")
        let unrelated = Self.item("flour", recipe: "Bread")
        let capturing = CapturingIntelligence(result: .cannedNotAGoodFit)
        let viewModel = ShoppingListViewModel(
            items: [target, sibling, unrelated],
            store: nil,
            intelligence: capturing
        )
        viewModel.beginSubstitution(for: target)
        await viewModel.generateSubstitution(reason: nil)
        #expect(capturing.capturedContext?.recipeTitle == "Asian Green Beans")
        // Only the same-recipe sibling, not the unrelated row, is included.
        #expect(capturing.capturedContext?.otherIngredients == ["soy sauce"])
    }

    // MARK: - Apply (options)

    @Test func applyReplacesTheRowWithTheChosenOption() async {
        let target = Self.item("1 cup buttermilk")
        let viewModel = Self.model(items: [target], substitution: .cannedButtermilkOptions)
        viewModel.beginSubstitution(for: target)
        await viewModel.generateSubstitution(reason: nil)
        viewModel.applySubstitution(.cannedButtermilk)

        #expect(viewModel.items.count == 1)
        #expect(viewModel.items.first?.id == target.id)
        #expect(viewModel.items.first?.ingredientText == IngredientSubstitution.cannedButtermilk.substitute)
        #expect(viewModel.items.first?.recipeTitle == "R")
        #expect(viewModel.substitution == .idle)
    }

    @Test func applyIsNoOpUnlessLoaded() {
        let viewModel = Self.model(items: [Self.item("1 cup buttermilk")])
        viewModel.applySubstitution(.cannedButtermilk)  // state is .idle
        #expect(viewModel.substitution == .idle)
        #expect(viewModel.items.first?.ingredientText == "1 cup buttermilk")
    }

    // MARK: - Omit ("leave it out")

    @Test func omitRemovesTheRow() async {
        let target = Self.item("chopped parsley")
        let viewModel = Self.model(items: [target], substitution: .cannedOmit)
        viewModel.beginSubstitution(for: target)
        await viewModel.generateSubstitution(reason: nil)
        viewModel.omitIngredient()

        #expect(viewModel.items.isEmpty)
        #expect(viewModel.substitution == .idle)
    }

    @Test func omitIsNoOpForAnOptionsResult() async {
        let target = Self.item("1 cup buttermilk")
        let viewModel = Self.model(items: [target], substitution: .cannedButtermilkOptions)
        viewModel.beginSubstitution(for: target)
        await viewModel.generateSubstitution(reason: nil)
        viewModel.omitIngredient()  // wrong verdict — must not remove the row
        #expect(viewModel.items.count == 1)
    }

    // MARK: - Not a good fit (allowed to say no)

    @Test func notAGoodFitKeepsTheRowAndOffersNoApply() async {
        let target = Self.item("green beans", recipe: "Asian Green Beans")
        let viewModel = Self.model(items: [target], substitution: .cannedNotAGoodFit)
        viewModel.beginSubstitution(for: target)
        await viewModel.generateSubstitution(reason: nil)

        if case .loaded(_, _, _, let result) = viewModel.substitution {
            #expect(result.verdict == SubstitutionResult.cannedNotAGoodFit.verdict)
        } else {
            Issue.record("expected a loaded not-a-good-fit result")
        }
        // Neither apply nor omit changes the row.
        viewModel.applySubstitution(.cannedButtermilk)
        viewModel.omitIngredient()
        #expect(viewModel.items.first?.ingredientText == "green beans")
    }

    @Test func dismissReturnsToIdle() async {
        let target = Self.item("1 cup buttermilk")
        let viewModel = Self.model(items: [target])
        viewModel.beginSubstitution(for: target)
        await viewModel.generateSubstitution(reason: nil)
        #expect(viewModel.substitution != .idle)
        viewModel.dismissSubstitution()
        #expect(viewModel.substitution == .idle)
    }
}

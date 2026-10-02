import DODIntelligence
import Foundation
import Testing

@testable import DODFeatureFeed

/// L1 coverage for the T-934 (US-54 / DUT-1382) "Ask Dutch Oven Daddy" helper
/// view model — availability + image-support gating, and the conversation
/// transcript built by `ask(imageData:)` (constitution §6 L1 mandate).
///
/// The live model is unavailable in the simulator / CI and non-deterministic,
/// so these drive a ``FakeIntelligenceService`` — the seam, never the model.
@MainActor
@Suite("CookingHelperViewModel (v2 AI)")
struct CookingHelperViewModelTests {

    private typealias Turn = CookingHelperViewModel.Turn

    // MARK: - Availability

    @Test func helperHiddenWhenNoServiceInjected() {
        #expect(!CookingHelperViewModel(intelligence: nil).isAvailable)
    }

    @Test func helperHiddenWhenServiceUnavailable() {
        #expect(!CookingHelperViewModel(intelligence: FakeIntelligenceService(isAvailable: false)).isAvailable)
    }

    @Test func helperShownWhenServiceAvailable() {
        #expect(CookingHelperViewModel(intelligence: FakeIntelligenceService(isAvailable: true)).isAvailable)
    }

    @Test func imageSupportReflectsTheService() {
        let withImages = CookingHelperViewModel(
            intelligence: FakeIntelligenceService(isAvailable: true, supportsImageInput: true)
        )
        let withoutImages = CookingHelperViewModel(
            intelligence: FakeIntelligenceService(isAvailable: true, supportsImageInput: false)
        )
        #expect(withImages.supportsImageInput)
        #expect(!withoutImages.supportsImageInput)
    }

    // MARK: - Ask

    @Test func askAppendsUserAndAssistantTurns() async {
        let viewModel = CookingHelperViewModel(
            intelligence: FakeIntelligenceService(isAvailable: true, answer: "Warm it gradually.")
        )
        viewModel.question = "How do I season a skillet?"
        await viewModel.ask(imageData: nil)

        #expect(viewModel.turns.count == 2)
        #expect(viewModel.turns.first?.role == .user)
        #expect(viewModel.turns.first?.text == "How do I season a skillet?")
        #expect(viewModel.turns.first?.hasImage == false)
        #expect(viewModel.turns.last?.role == .assistant)
        #expect(viewModel.turns.last?.text == "Warm it gradually.")
        #expect(viewModel.turns.last?.isEmptyResult == false)
        // The draft is cleared and the model is no longer responding.
        #expect(viewModel.question.isEmpty)
        #expect(!viewModel.isResponding)
    }

    @Test func askWithAnImageMarksTheUserTurn() async {
        let viewModel = CookingHelperViewModel(
            intelligence: FakeIntelligenceService(isAvailable: true, answer: "That pan looks well seasoned.")
        )
        // Image-only ask (no text) is allowed.
        await viewModel.ask(imageData: Data([0x01, 0x02]))

        #expect(viewModel.turns.first?.role == .user)
        #expect(viewModel.turns.first?.hasImage == true)
        #expect(viewModel.turns.last?.text == "That pan looks well seasoned.")
    }

    @Test func askWithNoResultAppendsAnEmptyResultTurn() async {
        let viewModel = CookingHelperViewModel(
            intelligence: FakeIntelligenceService(isAvailable: true, answer: nil)
        )
        viewModel.question = "How do I season a skillet?"
        await viewModel.ask(imageData: nil)

        #expect(viewModel.turns.last?.role == .assistant)
        #expect(viewModel.turns.last?.isEmptyResult == true)
    }

    @Test func askIsNoOpWhenUnavailable() async {
        let viewModel = CookingHelperViewModel(intelligence: FakeIntelligenceService(isAvailable: false))
        viewModel.question = "How do I season a skillet?"
        await viewModel.ask(imageData: nil)
        #expect(viewModel.turns.isEmpty)
    }

    @Test func askIsNoOpWhenBlankAndNoImage() async {
        let viewModel = CookingHelperViewModel(intelligence: FakeIntelligenceService(isAvailable: true))
        viewModel.question = "   "
        await viewModel.ask(imageData: nil)
        #expect(viewModel.turns.isEmpty)
    }

    @Test func resetClearsTheConversation() async {
        let viewModel = CookingHelperViewModel(
            intelligence: FakeIntelligenceService(isAvailable: true, answer: "Warm it gradually.")
        )
        viewModel.question = "How do I season a skillet?"
        await viewModel.ask(imageData: nil)
        #expect(!viewModel.turns.isEmpty)

        viewModel.reset()
        #expect(viewModel.turns.isEmpty)
        #expect(viewModel.question.isEmpty)
    }

    // MARK: - Recipe-scoped chat (DUT-1385)

    /// Records the recipe context it was handed.
    private final class ContextCapturingIntelligence: DODIntelligenceService, @unchecked Sendable {
        let isAvailable = true
        let supportsImageInput = false
        private(set) var capturedContext: String?
        func suggestSubstitution(
            for ingredient: String,
            in context: RecipeContext?,
            reason: SubstitutionReason?
        ) async -> SubstitutionResult? { nil }
        func summarize(_ text: String) async -> String? { nil }
        func answer(_ question: String, imageData: Data?, recipeContext: String?) async -> String? {
            capturedContext = recipeContext
            return "Use 1 tsp."
        }
    }

    @Test func recipeContextRidesAlongWithEachQuestion() async {
        let capturing = ContextCapturingIntelligence()
        let viewModel = CookingHelperViewModel(intelligence: capturing, recipeContext: "Recipe: Chili")
        viewModel.question = "How much salt?"
        await viewModel.ask(imageData: nil)
        #expect(capturing.capturedContext == "Recipe: Chili")
        #expect(viewModel.turns.last?.text == "Use 1 tsp.")
    }

    @Test func generalHelperSendsNoRecipeContext() async {
        let capturing = ContextCapturingIntelligence()
        let viewModel = CookingHelperViewModel(intelligence: capturing)
        viewModel.question = "How many cups in a gallon?"
        await viewModel.ask(imageData: nil)
        #expect(capturing.capturedContext == nil)
    }

    @Test func recipeConfigurationUsesRecipeCopy() {
        let config = CookingHelperSheet.Configuration.recipe("Skillet Chili")
        #expect(config.title == "Ask About This Recipe")
        #expect(config.emptyTitle == "Skillet Chili")
        #expect(config.placeholder == "Ask about this recipe")
        #expect(CookingHelperSheet.Configuration.general.title == "Ask Dutch Oven Daddy")
    }
}

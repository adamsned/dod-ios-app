import DODDomain
import DODSupport
import Foundation
import Testing

@testable import DODIntelligence

/// L1 coverage for the on-device intelligence seam (constitution §6 L1
/// mandate). The live FoundationModels model is unavailable in the simulator /
/// CI and non-deterministic, so these tests exercise the SEAM and the
/// availability GATING — never the model itself.
@Suite("DODIntelligence")
struct DODIntelligenceServiceTests {

    // MARK: - IngredientSubstitution value type

    @Test func substitutionIsEquatableByFields() {
        let base = IngredientSubstitution(substitute: "1 cup X", note: "use it")
        let same = IngredientSubstitution(substitute: "1 cup X", note: "use it")
        let different = IngredientSubstitution(substitute: "1 cup Y", note: "use it")
        #expect(base == same)
        #expect(base != different)
    }

    @Test func cannedFixtureIsStable() {
        #expect(IngredientSubstitution.cannedButtermilk.substitute == "1 cup milk + 1 tbsp lemon juice")
        #expect(!IngredientSubstitution.cannedButtermilk.note.isEmpty)
    }

    // MARK: - FakeIntelligenceService

    @Test func fakeAvailableReturnsCannedResult() async {
        let service = FakeIntelligenceService()
        #expect(service.isAvailable)
        let result = await service.suggestSubstitution(for: "buttermilk")
        #expect(result == .cannedButtermilkOptions)
    }

    @Test func fakeUnavailableHidesAvailabilityAndReturnsNil() async {
        let service = FakeIntelligenceService(isAvailable: false)
        #expect(!service.isAvailable)
        let result = await service.suggestSubstitution(for: "buttermilk")
        #expect(result == nil)
    }

    @Test func fakeAvailableButNoSuggestionReturnsNil() async {
        let service = FakeIntelligenceService(isAvailable: true, substitution: nil)
        #expect(service.isAvailable)
        let result = await service.suggestSubstitution(for: "buttermilk")
        #expect(result == nil)
    }

    // MARK: - LiveDODIntelligenceService (guarded fall-through)

    /// On the macOS test host — and on iOS 17-25 / the simulator / incapable
    /// hardware — FoundationModels is unavailable, so the live service must
    /// report `isAvailable == false`. We can't run the model, so this asserts
    /// the availability gate degrades correctly.
    @Test func liveServiceIsUnavailableWithoutModel() {
        #expect(!LiveDODIntelligenceService().isAvailable)
    }

    /// The live service must never throw and must return `nil` when the model
    /// is unavailable (the driving condition on the test host). Confirms the
    /// guarded fall-through: unavailable → nil, no crash.
    @Test func liveServiceReturnsNilWhenUnavailable() async {
        let result = await LiveDODIntelligenceService().suggestSubstitution(for: "buttermilk")
        #expect(result == nil)
    }

    /// Empty / whitespace input short-circuits to `nil` before any model touch.
    @Test func liveServiceRejectsEmptyInput() async {
        let result = await LiveDODIntelligenceService().suggestSubstitution(for: "   ")
        #expect(result == nil)
    }

    // MARK: - Reason-aware substitution + summary + answer (T-932 / T-933 / T-934)

    /// The context- and reason-carrying signature still returns the canned result
    /// when the fake is available (context + reason only shape the live prompt).
    @Test func fakeSubstitutionAcceptsContextAndReason() async {
        let service = FakeIntelligenceService()
        let context = RecipeContext(recipeTitle: "Asian Green Beans", otherIngredients: ["soy sauce"])
        let result = await service.suggestSubstitution(for: "1 cup buttermilk", in: context, reason: .dairyFree)
        #expect(result == .cannedButtermilkOptions)
    }

    // MARK: - Result verdicts + reason safety helpers (US-54 follow-up)

    @Test func cannedResultFixturesCarryTheRightVerdicts() {
        if case .options(let options) = SubstitutionResult.cannedButtermilkOptions.verdict {
            #expect(options.count == 2)
            #expect(options.first == .cannedButtermilk)
        } else {
            Issue.record("cannedButtermilkOptions should be an options verdict")
        }
        if case .omit = SubstitutionResult.cannedOmit.verdict {
        } else {
            Issue.record("cannedOmit should be an omit verdict")
        }
        if case .notAGoodFit = SubstitutionResult.cannedNotAGoodFit.verdict {
        } else {
            Issue.record("cannedNotAGoodFit should be a notAGoodFit verdict")
        }
    }

    @Test func allergyReasonHelpers() {
        #expect(SubstitutionReason.allergy.isAllergy)
        #expect(SubstitutionReason.allergy.requiresAllergenWarning)
        #expect(SubstitutionReason.sensitivity.requiresAllergenWarning)
        #expect(!SubstitutionReason.sensitivity.isAllergy)
        #expect(!SubstitutionReason.dairyFree.requiresAllergenWarning)
        #expect(!SubstitutionReason.outOfIt.isAllergy)
    }

    @Test func recipeContextHoldsFields() {
        let context = RecipeContext(recipeTitle: "Chili", otherIngredients: ["beans", "onion"])
        #expect(context.recipeTitle == "Chili")
        #expect(context.otherIngredients == ["beans", "onion"])
        #expect(RecipeContext(recipeTitle: "X").otherIngredients.isEmpty)
    }

    /// `summarize` / `answer` return their canned strings when available and
    /// `nil` when the device is unsupported (affordance hidden).
    @Test func fakeSummaryAndAnswerGateOnAvailability() async {
        let available = FakeIntelligenceService(summary: "S", answer: "A")
        #expect(await available.summarize("some recipe body") == "S")
        #expect(await available.answer("how do I season a skillet?") == "A")

        let unavailable = FakeIntelligenceService(isAvailable: false)
        #expect(await unavailable.summarize("body") == nil)
        #expect(await unavailable.answer("q") == nil)
    }

    /// `answer(_:imageData:)` returns the canned answer whether or not a photo is
    /// attached (the fake ignores the bytes); the live model path is iOS-only.
    @Test func fakeAnswerAcceptsImageData() async {
        let service = FakeIntelligenceService(answer: "A")
        #expect(await service.answer("what's wrong with this pan?", imageData: Data([0x01])) == "A")
        #expect(await service.answer("text only", imageData: nil) == "A")
    }

    /// Image support is injectable on the fake and `false` on the live service
    /// without a model (the macOS test host / unsupported device).
    @Test func imageSupportGating() {
        #expect(FakeIntelligenceService(supportsImageInput: true).supportsImageInput)
        #expect(!FakeIntelligenceService(supportsImageInput: false).supportsImageInput)
        #expect(!LiveDODIntelligenceService().supportsImageInput)
    }

    /// Every reason maps to a non-empty Title Case label + a prompt clause.
    @Test func substitutionReasonsHaveLabelsAndClauses() {
        for reason in SubstitutionReason.allCases {
            #expect(!reason.title.isEmpty)
            #expect(!reason.promptClause.isEmpty)
        }
        #expect(SubstitutionReason.lowerCarb.title == "Lower Carb")
    }

    // MARK: - Recipe chat prompt (DUT-1385)

    @Test func chatPromptWithoutContextIsJustTheQuestion() {
        #expect(LiveDODIntelligenceService.chatPrompt(question: "q", recipeContext: nil) == "q")
        #expect(LiveDODIntelligenceService.chatPrompt(question: "q", recipeContext: "") == "q")
    }

    @Test func chatPromptWithContextIncludesRecipeAndQuestion() {
        let prompt = LiveDODIntelligenceService.chatPrompt(question: "How much salt?", recipeContext: "Recipe: Chili")
        #expect(prompt.contains("Recipe: Chili"))
        #expect(prompt.hasSuffix("Their question: How much salt?"))
    }

    @Test func fakeAnswerAcceptsRecipeContext() async {
        let service = FakeIntelligenceService(answer: "A")
        #expect(await service.answer("q", imageData: nil, recipeContext: "Recipe: X") == "A")
    }

    /// Test the default implementation of checkDoneness for older conformers
    @Test func checkDonenessReturnsNilWithDefaultImplementation() async {
        let bare = makeBareService()
        #expect(await bare.checkDoneness(photo: Data([1]), stepText: "Bake until golden") == nil)
    }

    @Test func defaultAskHeatCoachReturnsNil() async {
        struct Bare: DODIntelligenceService {
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
        #expect(await Bare().askHeatCoach("windy?", ovenDiameterInches: 12, isBaking: false) == nil)
    }

    @Test func scanRecipeCardDefaultsToNil() async {
        #expect(await makeLegacyService().scanRecipeCard(imageData: Data([1, 2, 3])) == nil)
    }

    @Test func fakeScanReturnsCannedRecipe() async {
        let result = await FakeIntelligenceService().scanRecipeCard(imageData: Data([1]))
        #expect(result?.title == "Grandma's Gumbo")
    }

    @Test func fakeScanNilWhenUnavailable() async {
        let service = FakeIntelligenceService(isAvailable: false)
        #expect(await service.scanRecipeCard(imageData: Data([1])) == nil)
    }

    @Test func fakeScanNilWithoutImageSupport() async {
        let service = FakeIntelligenceService(supportsImageInput: false)
        #expect(await service.scanRecipeCard(imageData: Data([1])) == nil)
    }

    @Test func liveScanRejectsEmptyAndGarbageBytes() async {
        let service = LiveDODIntelligenceService()
        #expect(await service.scanRecipeCard(imageData: Data()) == nil)
        #expect(await service.scanRecipeCard(imageData: Data([0, 1, 2, 3])) == nil)
    }

    // MARK: - Explain Step (DUT-1021)

    @Test func fakeExplainStepReturnsCannedWhenAvailable() async {
        let service = FakeIntelligenceService()
        #expect(await service.explainStep("Fold in the egg whites", nextStep: nil) == .canned)
    }

    @Test func fakeExplainStepNilWhenUnavailable() async {
        let service = FakeIntelligenceService(isAvailable: false)
        #expect(await service.explainStep("Fold in the egg whites", nextStep: nil) == nil)
    }

    @Test func defaultExtractRecipeReturnsNil() {
        let bare = makeBareService()
        let result = bare.extractRecipe(fromBody: "x")
        #expect(result == nil)
    }

    @Test func fakeExtractRecipeReturnsCannedWhenAvailable() async {
        let extraction = ExtractedRecipe(ingredients: ["1 cup flour"], instructions: ["Mix."])
        let service = FakeIntelligenceService(extraction: extraction)
        #expect(await service.extractRecipe(fromBody: "some body") == extraction)
    }

    @Test func fakeExtractRecipeReturnsNilWhenUnavailable() async {
        let service = FakeIntelligenceService(
            isAvailable: false,
            extraction: ExtractedRecipe(ingredients: ["1 cup flour"], instructions: ["Mix."])
        )
        #expect(await service.extractRecipe(fromBody: "some body") == nil)
    }

    @Test func fakeExtractRecipeReturnsNilWithDefault() async {
        let service = FakeIntelligenceService()
        #expect(await service.extractRecipe(fromBody: "some body") == nil)
    }

    @Test func fakeServiceClassifyAisleDefaultsToNil() async {
        let service = FakeIntelligenceService()  // match the init style used in this file
        #expect(await service.classifyAisle("1 tbsp gochujang") == nil)
    }

    @Test func defaultSummarizeCommentsIsNil() async {
        let bare = makeBareService()
        #expect(await bare.summarizeComments(["x"]) == nil)
    }

    @Test func fakeReturnsCannedDigestWhenAvailable() async {
        let service = FakeIntelligenceService(commentDigest: .canned)
        #expect(await service.summarizeComments(["a"]) == .canned)
    }

    @Test func fakeReturnsNilWhenUnavailable() async {
        let service = FakeIntelligenceService(isAvailable: false, commentDigest: .canned)
        #expect(await service.summarizeComments(["a"]) == nil)
    }

    @Test func fakeNilDigestModelsNoResult() async {
        let service = FakeIntelligenceService(commentDigest: nil)
        #expect(await service.summarizeComments(["a"]) == nil)
    }

    @Test func liveIdentifyIngredientsIsEmptyWithoutModel() async {
        let result = await LiveDODIntelligenceService().identifyIngredients(imageData: Data([0x00]))
        #expect(result.isEmpty)
    }

    @Test func captionMomentDefaultsToNil() async {
        let request = MomentCaptionRequest(recipeTitle: "X", note: "n")
        #expect(await makeBareService().captionMoment(request) == nil)
    }

    @Test func fakeCaptionMomentReturnsCannedWhenAvailable() async {
        let service = FakeIntelligenceService()
        let request = MomentCaptionRequest(recipeTitle: "X", note: "yum")
        #expect(await service.captionMoment(request) != nil)
    }

    @Test func fakeCaptionMomentNilWhenUnavailableOrEmptyMoment() async {
        // unavailable service returns nil
        let unavailableService = FakeIntelligenceService(isAvailable: false)
        let request = MomentCaptionRequest(recipeTitle: "X", note: "yum")
        #expect(await unavailableService.captionMoment(request) == nil)

        // empty moment (title only) returns nil
        let service = FakeIntelligenceService()
        let emptyRequest = MomentCaptionRequest(recipeTitle: "X", note: "")
        #expect(await service.captionMoment(emptyRequest) == nil)
    }

    @Test func fakeHeatCoachReturnsCannedWhenAvailable() async {
        let service = FakeIntelligenceService()
        #expect(await service.askHeatCoach("windy at 6000ft?", ovenDiameterInches: 12, isBaking: false) != nil)
    }

    @Test func fakeHeatCoachNilWhenUnavailableOrEmpty() async {
        #expect(
            await FakeIntelligenceService(isAvailable: false).askHeatCoach("x", ovenDiameterInches: 12, isBaking: false)
                == nil
        )
        #expect(await FakeIntelligenceService().askHeatCoach("   ", ovenDiameterInches: 12, isBaking: false) == nil)
    }

    @Test func liveCaptionMomentNilOnTestHost() async {
        #expect(await LiveDODIntelligenceService().captionMoment(.init(recipeTitle: "X", note: "great")) == nil)
    }

    @Test func liveCaptionMomentNilWithoutMoment() async {
        #expect(await LiveDODIntelligenceService().captionMoment(.init(recipeTitle: "X", note: "")) == nil)
    }
}

// MARK: - Helper functions

extension DODIntelligenceServiceTests {
    private func makeBareService() -> some DODIntelligenceService {
        struct Bare: DODIntelligenceService {
            var isAvailable: Bool { true }
            var supportsImageInput: Bool { true }
            func suggestSubstitution(
                for ingredient: String,
                in context: RecipeContext?,
                reason: SubstitutionReason?
            ) async -> SubstitutionResult? { nil }
            func summarize(_ text: String) async -> String? { nil }
            func answer(_ question: String, imageData: Data?, recipeContext: String?) async -> String? { nil }
        }
        return Bare()
    }

    private func makeLegacyService() -> some DODIntelligenceService {
        struct LegacyService: DODIntelligenceService {
            var isAvailable: Bool { true }
            var supportsImageInput: Bool { true }
            func suggestSubstitution(
                for ingredient: String,
                in context: RecipeContext?,
                reason: SubstitutionReason?
            ) async -> SubstitutionResult? { nil }
            func summarize(_ text: String) async -> String? { nil }
            func answer(_ question: String, imageData: Data?, recipeContext: String?) async -> String? { nil }
        }
        return LegacyService()
    }
}

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

    /// Every reason maps to a non-empty Title Case label + a prompt clause.
    @Test func substitutionReasonsHaveLabelsAndClauses() {
        for reason in SubstitutionReason.allCases {
            #expect(!reason.title.isEmpty)
            #expect(!reason.promptClause.isEmpty)
        }
        #expect(SubstitutionReason.lowerCarb.title == "Lower Carb")
    }
}

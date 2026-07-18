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

    @Test func fakeAvailableReturnsCannedSubstitution() async {
        let service = FakeIntelligenceService()
        #expect(service.isAvailable)
        let result = await service.suggestSubstitution(for: "buttermilk")
        #expect(result == .cannedButtermilk)
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
}

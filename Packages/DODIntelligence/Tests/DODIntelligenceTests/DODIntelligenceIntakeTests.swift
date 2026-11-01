import DODDomain
import DODSupport
import Foundation
import Testing

@testable import DODIntelligence

/// DUT-1032 — the intake requirement defaults to `nil` for conformers that don't override it.
@Suite("DODIntelligence intake")
struct DODIntelligenceIntakeTests {

    private struct NoIntake: DODIntelligenceService {
        var isAvailable: Bool { false }
        var supportsImageInput: Bool { false }
        func suggestSubstitution(
            for ingredient: String,
            in context: RecipeContext?,
            reason: SubstitutionReason?
        ) async -> SubstitutionResult? { nil }
        func summarize(_ text: String) async -> String? { nil }
        func answer(_ question: String, imageData: Data?, recipeContext: String?) async -> String? { nil }
    }

    @Test func intakeDefaultsToNilForConformersThatDontOverride() async {
        let answers = [IntakeAnswer(question: "q", answer: "a")]
        #expect(await NoIntake().extractIntakeProfile(from: answers) == nil)
    }
}

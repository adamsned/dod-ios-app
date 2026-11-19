import DODSupport
import Foundation

#if os(iOS)
import FoundationModels
#endif

// The on-device onboarding-intake turn (DUT-1032). iOS-26-only: the
// FoundationModels schema is inside `#if os(iOS)` + `@available(iOS 26, *)`,
// and the public entry point returns `nil` off-iOS / pre-26 / when empty.
extension LiveDODIntelligenceService {

    public func extractIntakeProfile(from answers: [IntakeAnswer]) async -> CookIntakeProfile? {
        guard !answers.isEmpty else { return nil }
        #if os(iOS)
        if #available(iOS 26, *) {
            return await Self.generateIntakeProfile(from: answers)
        }
        #endif
        return nil
    }

    #if os(iOS)
    /// Re-checks availability, runs one structured turn, and maps the reply
    /// through the pure ``CookIntakeProfile/normalized(fear:occasion:household:worry:)``.
    /// Any error (including a guardrail rejection) is swallowed to `nil`.
    @available(iOS 26, *)
    static func generateIntakeProfile(from answers: [IntakeAnswer]) async -> CookIntakeProfile? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }
        let session = LanguageModelSession(instructions: intakeInstructions)
        let transcript = answers.map { "Q: \($0.question)\nA: \($0.answer)" }.joined(separator: "\n\n")
        do {
            let reply = try await session.respond(to: transcript, generating: GenerableIntakeProfile.self)
            let content = reply.content
            return CookIntakeProfile.normalized(
                fear: content.fearLevel,
                occasion: content.occasion,
                household: content.householdSize,
                worry: content.biggestWorry
            )
        } catch {
            return nil
        }
    }

    @available(iOS 26, *)
    private static let intakeInstructions = """
        You read a short welcome conversation with a brand-new cast-iron and \
        Dutch-oven cook and fill in their profile. Only use what they said; if \
        something was not mentioned pick the most neutral value. Do not add commentary.
        """

    @available(iOS 26, *)
    @Generable
    struct GenerableIntakeProfile {
        @Guide(description: "Exactly one of: nervous, cautious, confident — how intimidated the cook is.")
        var fearLevel: String
        @Guide(description: "Exactly one of: weeknightDinner, weekendCook, campout, entertaining, other.")
        var occasion: String
        @Guide(description: "Number of people they usually cook for, 1 to 12.", .range(1...12))
        var householdSize: Int
        @Guide(description: "What scares them most, in at most 8 words; empty if not said.")
        var biggestWorry: String
    }
    #endif
}

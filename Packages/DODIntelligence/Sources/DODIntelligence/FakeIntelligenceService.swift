import DODDomain
import Foundation

/// A deterministic ``DODIntelligenceService`` for L1 tests, SwiftUI previews,
/// and any opt-in L4 snapshot.
///
/// The live on-device model is non-deterministic AND unavailable in the
/// simulator / CI, so it must never run in a per-PR gate. This fake stands in
/// for it: `isAvailable` and the returned substitution are both injectable, so a
/// test can exercise the "available → returns a suggestion" seam and the
/// "unavailable → affordance hidden" seam without touching FoundationModels.
///
/// It ships in the main target (not a test-only target) so feature packages'
/// previews and the App's UI-test launch-arg hook can inject it too — mirroring
/// how the shopping-list `.mock` fixture lives alongside production code.
public struct FakeIntelligenceService: DODIntelligenceService {

    public let isAvailable: Bool
    public let supportsImageInput: Bool
    private let cannedSubstitution: SubstitutionResult?
    private let cannedSummary: String?
    private let cannedAnswer: String?
    private let cannedDoneness: DonenessCheckResult?
    private let cannedExplanation: StepExplanation?
    private let cannedRecipeAnswer: String?
    private let cannedExtraction: ExtractedRecipe?
    private let cannedDigest: CommentDigest?
    private let cannedMomentCaption: String?

    /// - Parameters:
    ///   - isAvailable: What ``isAvailable`` reports. Pass `false` to model an
    ///     unsupported device (every AI affordance stays hidden).
    ///   - substitution: What ``suggestSubstitution(for:in:reason:)`` returns
    ///     when available. Pass `nil` to model the graceful "no substitute found"
    ///     path. Defaults to ``SubstitutionResult/cannedButtermilkOptions``.
    ///   - summary: What ``summarize(_:)`` returns when available. `nil` models
    ///     the graceful no-result path.
    ///   - answer: What ``answer(_:)`` returns when available. `nil` models the
    ///     graceful no-result path.
    ///   - doneness: What ``checkDoneness(photo:stepText:)`` returns when available. `nil` models
    ///     the graceful no-result path.
    ///   - recipeCard: What ``scanRecipeCard(imageData:)`` returns when available and image input is supported. `nil` models the graceful no-result path.
    ///   - explanation: What ``explainStep(_:)`` returns when available. `nil` models
    ///     the graceful no-result path. Defaults to ``StepExplanation/canned``.
    ///   - extraction: What ``extractRecipe(fromBody:)`` returns when available. `nil` models
    ///     the graceful no-result path.
    ///   - commentDigest: What ``summarizeComments(_:)`` returns when available. `nil` models
    ///     the graceful no-result path. Defaults to ``CommentDigest/canned``.
    ///   - momentCaption: What ``captionMoment(_:)`` returns when available. `nil` models
    ///     the graceful no-result path.
    ///   - recipeAnswer: What ``askRecipe(_:toolbox:)`` returns when available. nil models the no-result path.
    public init(
        isAvailable: Bool = true,
        supportsImageInput: Bool = true,
        substitution: SubstitutionResult? = .cannedButtermilkOptions,
        summary: String? = "A quick, weeknight-friendly cast-iron recipe with simple pantry ingredients.",
        answer: String? = "Warm the pan gradually, add a thin layer of oil, and wipe out any excess before cooking.",
        doneness: DonenessCheckResult? = DonenessCheckResult(
            verdict: .looksDone,
            confidence: 0.9,
            reassurance: "The crust is an even golden brown and the edges look set."
        ),
        explanation: StepExplanation? = .canned,
        recipeAnswer: String? = "Yes. Chill it overnight and reheat gently.",
        extraction: ExtractedRecipe? = nil,
        commentDigest: CommentDigest? = .canned,
        momentCaption: String? = "Look at that golden crust — you made this, and everyone is going to ask for seconds."
    ) {
        self.isAvailable = isAvailable
        self.supportsImageInput = supportsImageInput
        self.cannedSubstitution = substitution
        self.cannedSummary = summary
        self.cannedAnswer = answer
        self.cannedDoneness = doneness
        self.cannedExplanation = explanation
        self.cannedRecipeAnswer = recipeAnswer
        self.cannedExtraction = extraction
        self.cannedDigest = commentDigest
        self.cannedMomentCaption = momentCaption
    }

    public func suggestSubstitution(
        for ingredient: String,
        in context: RecipeContext?,
        reason: SubstitutionReason?
    ) async -> SubstitutionResult? {
        guard isAvailable else { return nil }
        return cannedSubstitution
    }

    public func summarize(_ text: String) async -> String? {
        guard isAvailable else { return nil }
        return cannedSummary
    }

    public func answer(_ question: String, imageData: Data?, recipeContext: String?) async -> String? {
        guard isAvailable else { return nil }
        return cannedAnswer
    }

    public func checkDoneness(photo: Data, stepText: String) async -> DonenessCheckResult? {
        guard isAvailable, supportsImageInput, !photo.isEmpty else { return nil }
        return cannedDoneness
    }

    public func explainStep(_ step: String, nextStep: String?) async -> StepExplanation? {
        guard isAvailable else { return nil }
        return cannedExplanation
    }

    public func extractRecipe(fromBody body: String) async -> ExtractedRecipe? {
        guard isAvailable else { return nil }
        return cannedExtraction
    }

    public func summarizeComments(_ comments: [String]) async -> CommentDigest? {
        guard isAvailable else { return nil }
        return cannedDigest
    }

    public func captionMoment(_ request: MomentCaptionRequest) async -> String? {
        guard isAvailable, request.hasMoment else { return nil }
        return cannedMomentCaption
    }

    public func askRecipe(_ question: String, toolbox: AskRecipeToolbox) async -> String? {
        guard isAvailable else { return nil }
        return cannedRecipeAnswer
    }
}

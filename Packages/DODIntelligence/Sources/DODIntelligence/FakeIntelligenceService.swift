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
    private let cannedSubstitution: SubstitutionResult?
    private let cannedSummary: String?
    private let cannedAnswer: String?

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
    public init(
        isAvailable: Bool = true,
        substitution: SubstitutionResult? = .cannedButtermilkOptions,
        summary: String? = "A quick, weeknight-friendly cast-iron recipe with simple pantry ingredients.",
        answer: String? = "Warm the pan gradually, add a thin layer of oil, and wipe out any excess before cooking."
    ) {
        self.isAvailable = isAvailable
        self.cannedSubstitution = substitution
        self.cannedSummary = summary
        self.cannedAnswer = answer
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

    public func answer(_ question: String) async -> String? {
        guard isAvailable else { return nil }
        return cannedAnswer
    }
}

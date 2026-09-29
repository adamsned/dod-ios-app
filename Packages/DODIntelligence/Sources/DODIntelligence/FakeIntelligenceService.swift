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
    private let cannedSubstitution: IngredientSubstitution?

    /// - Parameters:
    ///   - isAvailable: What ``isAvailable`` reports. Pass `false` to model an
    ///     unsupported device (the substitution affordance stays hidden).
    ///   - substitution: What ``suggestSubstitution(for:)`` returns when
    ///     available. Pass `nil` to model the graceful "no substitute found"
    ///     path. Defaults to ``IngredientSubstitution/cannedButtermilk``.
    public init(
        isAvailable: Bool = true,
        substitution: IngredientSubstitution? = .cannedButtermilk
    ) {
        self.isAvailable = isAvailable
        self.cannedSubstitution = substitution
    }

    public func suggestSubstitution(for ingredient: String) async -> IngredientSubstitution? {
        guard isAvailable else { return nil }
        return cannedSubstitution
    }
}

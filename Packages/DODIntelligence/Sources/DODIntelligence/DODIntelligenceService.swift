import Foundation

/// The app's shared on-device intelligence seam.
///
/// **Why a protocol.** The production conformance
/// (``LiveDODIntelligenceService``) is backed by Apple's FoundationModels
/// framework, which is iOS-26-only and unavailable on incapable hardware, in
/// the simulator, and on the macOS `swift test` slice. Feature code (the
/// Shopping List, and later summaries etc.) depends only on this protocol and
/// the plain ``IngredientSubstitution`` value type, so no feature package —
/// and none of the per-PR test gates — ever imports FoundationModels. Tests and
/// snapshots inject ``FakeIntelligenceService`` for a deterministic result.
///
/// **Graceful degradation is the contract.** ``isAvailable`` is the single gate
/// callers check before offering an AI affordance; when it is `false` the
/// affordance must be hidden entirely (no dead button). ``suggestSubstitution``
/// never throws to the UI — it returns `nil` on unavailability, model error, or
/// a safety-guardrail rejection, and the caller shows a graceful "no
/// substitute found" instead.
///
/// The protocol is intentionally small but shaped to grow: later on-device
/// features (recipe summarization, etc.) add sibling methods here without
/// disturbing the substitution seam.
public protocol DODIntelligenceService: Sendable {

    /// `true` only when an on-device language model is actually usable right
    /// now: the OS is new enough (iOS 26+) AND the system model reports
    /// `.available` (Apple Intelligence enabled, eligible device, model
    /// downloaded). `false` everywhere else — iOS 17-25, incapable hardware,
    /// the simulator, and the macOS test host. Callers gate every AI affordance
    /// on this so unsupported devices see no dead controls.
    var isAvailable: Bool { get }

    /// Suggest what to do about an ingredient the cook wants to change, weighing
    /// its role in the actual dish (``RecipeContext``) and why they want to swap
    /// it (``SubstitutionReason``). `context: nil` asks in isolation;
    /// `reason: nil` asks for a general pantry swap.
    ///
    /// Returns a ``SubstitutionResult`` whose verdict may be one or more
    /// concrete options, "leave it out", or "not a good fit" (the ingredient is
    /// essential). Returns `nil` — never throws — when the service is
    /// unavailable, the input is empty, the model errors, or a safety guardrail
    /// rejects the request, so the UI degrades gracefully in every failure mode.
    func suggestSubstitution(
        for ingredient: String,
        in context: RecipeContext?,
        reason: SubstitutionReason?
    ) async -> SubstitutionResult?

    /// Summarize already-cached recipe or article body text into a few short
    /// sentences (US-54 / T-932). `text` is the on-device body; nothing is sent
    /// off-device. Returns `nil` — never throws — when unavailable, the input is
    /// empty, the model errors, or a guardrail rejects it, so the "Summarize"
    /// affordance degrades gracefully.
    func summarize(_ text: String) async -> String?

    /// Answer an on-device cast-iron / Dutch-oven / cooking-technique question
    /// for the Cooking Tools helper (US-54 / T-934). Returns `nil` — never
    /// throws — on unavailability / empty input / model error / guardrail
    /// rejection, so the helper degrades gracefully.
    func answer(_ question: String) async -> String?
}

extension DODIntelligenceService {

    /// Convenience for a context- and reason-free substitution, so previews and
    /// call sites that don't model either stay terse.
    public func suggestSubstitution(for ingredient: String) async -> SubstitutionResult? {
        await suggestSubstitution(for: ingredient, in: nil, reason: nil)
    }
}

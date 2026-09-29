import Foundation

#if os(iOS)
import FoundationModels
#endif

/// Production ``DODIntelligenceService`` backed by Apple's on-device
/// FoundationModels language model (iOS 26+).
///
/// **Availability gating mirrors ``SystemCookLiveActivityController``:** every
/// FoundationModels touch is wrapped in `#if os(iOS)` (so the macOS `swift test`
/// slice never links the framework) AND `@available(iOS 26, *)` (so the iOS-17
/// deployment target compiles) AND a runtime probe of
/// `SystemLanguageModel.default.availability` (so an eligible-OS-but-incapable
/// device degrades). On iOS 17-25, in the simulator, on incapable hardware, and
/// on macOS, ``isAvailable`` is `false` and ``suggestSubstitution`` returns
/// `nil` — the type still compiles and conforms everywhere, it just does
/// nothing where the model can't run.
///
/// No session is stored: a fresh ``LanguageModelSession`` is created per call,
/// which keeps this type free of non-`Sendable` stored state.
public final class LiveDODIntelligenceService: DODIntelligenceService {

    public init() {}

    public var isAvailable: Bool {
        #if os(iOS)
        if #available(iOS 26, *) {
            if case .available = SystemLanguageModel.default.availability {
                return true
            }
        }
        return false
        #else
        return false
        #endif
    }

    public func suggestSubstitution(
        for ingredient: String,
        reason: SubstitutionReason?
    ) async -> IngredientSubstitution? {
        let trimmed = ingredient.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        #if os(iOS)
        if #available(iOS 26, *) {
            return await Self.generateSubstitution(for: trimmed, reason: reason)
        }
        return nil
        #else
        return nil
        #endif
    }

    public func summarize(_ text: String) async -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        #if os(iOS)
        if #available(iOS 26, *) {
            return await Self.generateText(
                instructions: Self.summaryInstructions,
                // Cap the body so a very long article stays inside the model's
                // context window; the lede carries the gist.
                prompt: "Summarize this for a home cook:\n\n\(String(trimmed.prefix(4000)))"
            )
        }
        return nil
        #else
        return nil
        #endif
    }

    public func answer(_ question: String) async -> String? {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        #if os(iOS)
        if #available(iOS 26, *) {
            return await Self.generateText(
                instructions: Self.helperInstructions,
                prompt: trimmed
            )
        }
        return nil
        #else
        return nil
        #endif
    }

    #if os(iOS)
    /// The single place that touches the model. Re-checks availability (the
    /// affordance is gated on ``isAvailable``, but the state can change between
    /// the gate and the call), then runs one structured-output turn. Any
    /// error — including a safety-guardrail rejection — is swallowed to `nil`
    /// so a failed suggestion never surfaces as a thrown error in the UI.
    @available(iOS 26, *)
    private static func generateSubstitution(
        for ingredient: String,
        reason: SubstitutionReason?
    ) async -> IngredientSubstitution? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }
        let session = LanguageModelSession(instructions: instructions)
        // Fold the reason into the ask so the swap fits the need (a dairy-free
        // substitute reads very differently from a lower-carb one). No reason →
        // a general pantry swap.
        let prompt: String
        if let reason {
            prompt = "Suggest a substitute for '\(ingredient)' because \(reason.promptClause)."
        } else {
            prompt = "Suggest a common substitute for: \(ingredient)"
        }
        do {
            let reply = try await session.respond(to: prompt, generating: GenerableSubstitution.self)
            let content = reply.content
            return IngredientSubstitution(substitute: content.substitute, note: content.note)
        } catch {
            return nil
        }
    }

    /// Shared one-shot free-text turn for ``summarize(_:)`` and ``answer(_:)``.
    /// Re-checks availability, runs one plain-text turn under the given
    /// instructions, and swallows any error (including a guardrail rejection) to
    /// `nil` so a failure never surfaces as a thrown error in the UI.
    @available(iOS 26, *)
    private static func generateText(instructions: String, prompt: String) async -> String? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }
        let session = LanguageModelSession(instructions: instructions)
        do {
            let reply = try await session.respond(to: prompt)
            let text = reply.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        } catch {
            return nil
        }
    }

    /// Instructions for the recipe/article summary surface (T-932).
    @available(iOS 26, *)
    private static let summaryInstructions = """
        You are a concise cooking assistant. Summarize the given recipe or \
        article for a home cook in two or three short sentences: what it is and \
        what to expect. Do not invent details that are not in the text.
        """

    /// Instructions for the Cooking Tools question helper (T-934).
    @available(iOS 26, *)
    private static let helperInstructions = """
        You are a friendly cast-iron and Dutch-oven cooking expert. Answer the \
        cook's question with practical, safe, step-by-step guidance in a short \
        paragraph. Stick to cast iron, Dutch ovens, and cooking technique; if a \
        question is outside that, say so briefly.
        """

    /// System instructions scoping the model to concise, practical cooking
    /// substitutions. Kept terse — the structured `@Generable` output shape
    /// carries the formatting contract.
    @available(iOS 26, *)
    private static let instructions = """
        You are a concise cast-iron and Dutch-oven cooking assistant. Given a \
        single recipe ingredient, suggest one common pantry substitute a home \
        cook is likely to have. Keep the amount realistic and the guidance to \
        one short sentence. Do not add commentary beyond the requested fields.
        """

    /// The FoundationModels-native mirror of ``IngredientSubstitution``. Nested
    /// and non-public so it (and the framework it needs) never escapes this
    /// iOS-only compilation unit; the result is mapped onto the plain public
    /// value type before returning. Left at internal (not `private`) because the
    /// `@Generable` macro synthesizes a file-scoped conformance that must reach
    /// it. `@Guide` annotates each field for the structured-generation schema.
    @available(iOS 26, *)
    @Generable
    struct GenerableSubstitution {
        @Guide(description: "The substitute ingredient and amount, e.g. '1 cup milk + 1 tbsp lemon juice'")
        var substitute: String

        @Guide(description: "One short sentence on how to use it")
        var note: String
    }
    #endif
}

import Foundation

#if os(iOS)
import FoundationModels

// The FoundationModels image-attachment API (``Attachment`` / ``ImageAttachment``)
// only exists in the iOS 27 SDK. It must therefore be COMPILED OUT when building
// with an older SDK (CI + release run Xcode 26 on macos-15 runners, which has no
// iOS 27 SDK), or the build fails with "cannot find 'Attachment' in scope" even
// though every call is `@available(iOS 27, *)` gated at runtime. `compiler(>=6.4)`
// is the proxy: Xcode 27.1 ships Swift 6.4, Xcode 26 ships Swift 6.2. When the
// build toolchain reaches 27.1 the image path (and ``supportsImageInput``) light
// up automatically; until then this service is text-only. (DUT-1382.)
#if compiler(>=6.4)
import CoreGraphics
import ImageIO
#endif
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

    public var supportsImageInput: Bool {
        // Image attachments are an iOS 27 FoundationModels capability that needs
        // the iOS 27 SDK to COMPILE (see the import note). `false` whenever the
        // build toolchain is older (text-only) or the model can't run.
        #if os(iOS) && compiler(>=6.4)
        if #available(iOS 27, *) {
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
        in context: RecipeContext?,
        reason: SubstitutionReason?
    ) async -> SubstitutionResult? {
        let trimmed = ingredient.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        #if os(iOS)
        if #available(iOS 26, *) {
            return await Self.generateSubstitution(for: trimmed, context: context, reason: reason)
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

    public func answer(_ question: String, imageData: Data?, recipeContext: String?) async -> String? {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        // An image-only ask (no text) is allowed; a fully empty ask is not.
        guard !trimmed.isEmpty || imageData != nil else { return nil }
        #if os(iOS)
        #if compiler(>=6.4)
        // Image path is iOS-27-SDK-only (compiled out on older toolchains).
        if let imageData, #available(iOS 27, *) {
            if let withImage = await Self.generateAnswer(
                question: trimmed,
                imageData: imageData,
                recipeContext: recipeContext
            ) {
                return withImage
            }
            // The image path yielded nothing (decode or model error); fall back
            // to a text-only answer when there's still a question to answer.
        }
        #endif
        if #available(iOS 26, *), !trimmed.isEmpty {
            return await Self.generateText(
                instructions: recipeContext == nil ? Self.helperInstructions : Self.recipeChatInstructions,
                prompt: Self.chatPrompt(question: trimmed, recipeContext: recipeContext)
            )
        }
        return nil
        #else
        return nil
        #endif
    }

    /// DUT-1385 — the user turn for the helper chat. With a recipe, the recipe
    /// text (capped so a long recipe stays inside the context window) precedes
    /// the question; without one it is just the question.
    static func chatPrompt(question: String, recipeContext: String?) -> String {
        guard let recipeContext, !recipeContext.isEmpty else { return question }
        return """
            Here is the recipe the cook is making right now:

            \(String(recipeContext.prefix(6000)))

            Their question: \(question)
            """
    }

    #if os(iOS)
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

    // Image-grounded answering needs the iOS 27 SDK's ``Attachment`` type, so the
    // whole block is `compiler(>=6.4)`-gated (see the import note) and lights up
    // once the build toolchain is Xcode 27.1+.
    #if compiler(>=6.4)
    /// One image-grounded answer turn (iOS 27+). Decodes the attached photo and
    /// hands the model a multimodal prompt (text + image) so it can base its help
    /// on what it actually sees. Any error (bad image bytes, guardrail, model
    /// error) is swallowed to `nil` so the caller can fall back to text.
    @available(iOS 27, *)
    private static func generateAnswer(question: String, imageData: Data, recipeContext: String?) async -> String? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }
        guard let cgImage = decodeCGImage(from: imageData) else { return nil }
        let session = LanguageModelSession(
            instructions: recipeContext == nil ? helperInstructions : recipeChatInstructions
        )
        let text = chatPrompt(
            question: question.isEmpty ? "Look at this photo and help me with it." : question,
            recipeContext: recipeContext
        )
        do {
            let reply = try await session.respond {
                text
                Attachment(cgImage)
            }
            let answer = reply.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return answer.isEmpty ? nil : answer
        } catch {
            return nil
        }
    }

    /// Decode JPEG/PNG bytes into a `CGImage` for a FoundationModels image
    /// attachment. Returns `nil` on undecodable bytes so the caller degrades.
    @available(iOS 27, *)
    private static func decodeCGImage(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
    #endif

    /// Instructions for the recipe/article summary surface (T-932).
    @available(iOS 26, *)
    private static let summaryInstructions = """
        You are a concise cooking assistant. Summarize the given recipe or \
        article for a home cook in two or three short sentences: what it is and \
        what to expect. Do not invent details that are not in the text.
        """

    /// Instructions for the "Ask Dutch Oven Daddy" helper (T-934 / DUT-1382).
    ///
    /// Scope is any cooking or kitchen question (not just cast iron), and
    /// accuracy comes before folklore: the model is told to use correct,
    /// up-to-date knowledge and is given the soap example explicitly, because the
    /// old prompt let it repeat the "never use soap on cast iron" myth.
    @available(iOS 26, *)
    private static let helperInstructions = """
        You are Dutch Oven Daddy's friendly cooking assistant. You know cast iron \
        and Dutch ovens deeply, but you help with ANY cooking or kitchen \
        question: techniques, recipes, ingredient swaps, measurement conversions \
        (for example how many cups are in a gallon), food safety, and equipment. \
        Never refuse a cooking or kitchen question for being off topic; just \
        answer it. Only decline if a question has nothing to do with cooking or \
        the kitchen, and then say so briefly.

        Use broad, accurate, up-to-date knowledge, and value being correct over \
        being folksy. Do not repeat outdated kitchen myths. For example, a small \
        amount of mild dish soap is fine on modern seasoned cast iron and does \
        not ruin the seasoning; the old "never use soap" rule came from lye-based \
        soaps that no longer exist.

        Answer in a short, practical paragraph a home cook can act on. Be warm \
        but concise. Do not use em dashes; use periods or commas instead. When a \
        photo is attached, look at it and base your help on what you actually see.
        """

    /// DUT-1385 — instructions for Cook Mode's "Ask About This Recipe" chat:
    /// answers stay scoped to the one recipe, and the recipe text is the source
    /// of truth for amounts and times.
    @available(iOS 26, *)
    private static let recipeChatInstructions = """
        You are Dutch Oven Daddy's cooking assistant, helping someone who is \
        cooking the recipe they give you right now. Answer questions about this \
        recipe only: its ingredients and amounts, steps, timing, doneness, prep \
        and make-ahead, scaling, and swaps within it. Treat the recipe text as \
        the source of truth and quote its amounts and times exactly. If the \
        recipe does not say, give practical guidance and mention that the recipe \
        does not specify it. If a question has nothing to do with this recipe or \
        cooking it, say briefly that you can only help with this recipe.

        Answer in a short, practical paragraph. Do not use em dashes; use periods \
        or commas instead. When a photo is attached, relate what you see to this \
        recipe.
        """
    #endif
}

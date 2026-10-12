import Foundation

#if os(iOS)
import FoundationModels
#endif

// The on-device substitution turn, split out of `LiveDODIntelligenceService.swift`
// so that file stays well under the SwiftLint 400-line cap and the
// FoundationModels-only substitution schema lives next to the mapping that
// consumes it. iOS-26-only: everything here is inside `#if os(iOS)` +
// `@available(iOS 26, *)`, and the public entry point already returns `nil`
// off-iOS / pre-26 (see ``LiveDODIntelligenceService/suggestSubstitution(for:in:reason:)``).
extension LiveDODIntelligenceService {

    #if os(iOS)
    /// The single place that touches the model for substitutions. Re-checks
    /// availability (the affordance is gated on ``isAvailable``, but the state
    /// can change between the gate and the call), then runs one structured
    /// turn and maps the result onto the plain ``SubstitutionResult``. Any
    /// error — including a safety-guardrail rejection — is swallowed to `nil`
    /// so a failed suggestion never surfaces as a thrown error in the UI.
    @available(iOS 26, *)
    static func generateSubstitution(
        for ingredient: String,
        context: RecipeContext?,
        reason: SubstitutionReason?
    ) async -> SubstitutionResult? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }
        let session = LanguageModelSession(instructions: substitutionInstructions)
        do {
            let reply = try await session.respond(
                to: substitutionPrompt(for: ingredient, context: context, reason: reason),
                generating: GenerableSubstitution.self
            )
            return Self.map(reply.content)
        } catch {
            return nil
        }
    }

    /// Fold the ingredient, dish context and reason into one ask so the model
    /// can weigh the ingredient's ROLE in the actual dish rather than swapping in
    /// isolation (recipe-aware). Missing context / reason simply drop out.
    @available(iOS 26, *)
    private static func substitutionPrompt(
        for ingredient: String,
        context: RecipeContext?,
        reason: SubstitutionReason?
    ) -> String {
        var lines = ["Ingredient to change: \(ingredient)"]
        if let context {
            lines.append("Recipe: \(context.recipeTitle)")
            if !context.otherIngredients.isEmpty {
                lines.append("Other ingredients in the recipe: \(context.otherIngredients.joined(separator: "; "))")
            }
        }
        if let reason {
            lines.append("Reason for changing it: \(reason.promptClause).")
        }
        return lines.joined(separator: "\n")
    }

    /// Map the model's structured reply onto the plain result. Unknown / empty
    /// verdicts and an "options" verdict with no usable options both degrade to
    /// `nil` (the caller's graceful "no substitute found").
    @available(iOS 26, *)
    private static func map(_ content: GenerableSubstitution) -> SubstitutionResult? {
        let verdict = content.verdict.lowercased()
        let explanation = content.explanation.trimmingCharacters(in: .whitespacesAndNewlines)
        if verdict.contains("omit") {
            let note = explanation.isEmpty ? "You can leave this out without changing the dish much." : explanation
            return SubstitutionResult(verdict: .omit(note: note))
        }
        if verdict.contains("notagoodfit") || verdict.contains("not a good fit") || verdict.contains("essential") {
            let note =
                explanation.isEmpty
                ? "This ingredient is essential to the dish, so a substitute would change the recipe."
                : explanation
            return SubstitutionResult(verdict: .notAGoodFit(note: note))
        }
        let options =
            content.options
            .map {
                IngredientSubstitution(
                    substitute: $0.substitute.trimmingCharacters(in: .whitespacesAndNewlines),
                    note: $0.note.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
            .filter { !$0.substitute.isEmpty }
        guard !options.isEmpty else { return nil }
        return .options(Array(options.prefix(3)))
    }

    /// System instructions scoping the model to safe, recipe-aware substitutions
    /// with an explicit permission to decline. The structured `@Generable` shape
    /// carries the field contract; this carries the judgement.
    @available(iOS 26, *)
    private static let substitutionInstructions = """
        You are a careful cast-iron and Dutch-oven cooking assistant helping a \
        home cook change one ingredient. Consider the ingredient's role in the \
        specific dish, not just a generic "replace X with Y".

        Choose exactly one verdict:
        - "options": you can suggest one to three good substitutes a home cook is \
        likely to have. Put the best first. Keep each amount realistic and the \
        note to one short sentence.
        - "omit": the ingredient is optional or a garnish here and can simply be \
        left out. Explain briefly what to expect.
        - "notAGoodFit": the ingredient is fundamental to this dish, so no \
        substitute would keep it the same recipe. It is completely acceptable to \
        say there is no good substitution rather than invent a poor one.

        Safety: when the reason is an allergy or intolerance, every option must \
        fully avoid the ingredient and its obvious sources; if you are not sure a \
        swap is safe, prefer "omit" or "notAGoodFit" over a risky suggestion. \
        Never claim a substitute is allergen-free as a guarantee. Do not add \
        commentary beyond the requested fields.
        """

    /// The FoundationModels-native mirror of ``SubstitutionResult``. Nested and
    /// file-scoped so it (and the framework it needs) never escapes this
    /// iOS-only unit; mapped onto the plain public type before returning. A
    /// String `verdict` discriminator (not a Swift enum) keeps the schema
    /// robust; `@Guide` annotates each field for structured generation.
    @available(iOS 26, *)
    @Generable
    struct GenerableSubstitution {
        @Guide(
            description:
                "Exactly one of: options, omit, notAGoodFit. Use options when good substitutes exist; omit when the ingredient can be left out; notAGoodFit when it is essential to the dish."
        )
        var verdict: String

        @Guide(description: "One to three substitutes, best first. Only when verdict is options; otherwise empty.")
        var options: [GenerableOption]

        @Guide(
            description:
                "When verdict is omit or notAGoodFit, one short sentence explaining why. Empty when verdict is options."
        )
        var explanation: String
    }

    /// One substitute option inside ``GenerableSubstitution``.
    @available(iOS 26, *)
    @Generable
    struct GenerableOption {
        @Guide(description: "The substitute ingredient and amount, e.g. '1 cup milk + 1 tbsp lemon juice'")
        var substitute: String

        @Guide(description: "One short sentence on how to use it")
        var note: String
    }
    #endif
}

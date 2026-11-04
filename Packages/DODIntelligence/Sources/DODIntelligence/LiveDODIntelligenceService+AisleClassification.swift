import DODSupport
import Foundation

#if os(iOS)
import FoundationModels
#endif

// DUT-1006: on-device aisle fallback. Only called when the static keyword map
// returned `.other`. Strictly on-device (no network / PCC).
extension LiveDODIntelligenceService {

    /// Pure, platform-independent mapping from the model's raw case name to an
    /// `Aisle`. Unknown values map to `nil` (caller keeps `.other`).
    static func aisle(fromRaw raw: String) -> IngredientAisleClassifier.Aisle? {
        IngredientAisleClassifier.Aisle(
            rawValue: raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        )
    }

    public func classifyAisle(_ ingredient: String) async -> IngredientAisleClassifier.Aisle? {
        let trimmed = ingredient.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        #if os(iOS)
        if #available(iOS 26, *) {
            return await Self.generateAisle(for: trimmed)
        }
        #endif
        return nil
    }

    #if os(iOS)
    @available(iOS 26, *)
    static func generateAisle(for ingredient: String) async -> IngredientAisleClassifier.Aisle? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }
        let session = LanguageModelSession(
            instructions: """
                You sort one grocery-list ingredient line into the store aisle where a \
                shopper would find it. Choose exactly one aisle. Use \"other\" only if \
                none fit. Reply with the aisle only.
                """
        )
        do {
            let reply = try await session.respond(
                to: "Ingredient: \(ingredient)",
                generating: GenerableAisle.self
            )
            return aisle(fromRaw: reply.content.rawValue)
        } catch {
            return nil
        }
    }

    /// Constrained to the six `Aisle` cases (names match `Aisle.rawValue`).
    @available(iOS 26, *)
    @Generable
    enum GenerableAisle: String {
        case produce, meat, dairy, pantry, spices, other
    }
    #endif
}

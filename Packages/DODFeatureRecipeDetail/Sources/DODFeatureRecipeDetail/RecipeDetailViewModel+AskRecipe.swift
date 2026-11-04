import DODDomain
import DODIntelligence
import DODSupport
import Foundation

public struct AskRecipeMessage: Equatable, Sendable, Identifiable {
    public enum Role: Sendable { case user, assistant }
    public let id = UUID()
    public let role: Role
    public let text: String

    public init(role: Role, text: String) {
        self.role = role
        self.text = text
    }
}

extension RecipeDetailViewModel {
    public var isAskRecipeAvailable: Bool { recipe != nil && (intelligence?.isAvailable ?? false) }

    /// Built from the loaded recipe; ingredients scaled exactly like the list.
    func makeAskToolbox() -> AskRecipeToolbox? {
        guard let recipe else { return nil }
        let factor = servingsScaleFactor
        return AskRecipeToolbox(
            title: recipe.title,
            servings: userServings,
            scaledIngredients: recipe.ingredients.map { FractionRenderer.scale($0.text, by: factor) },
            steps: recipe.instructions.sorted { $0.step < $1.step }.map(\.text)
        )
    }

    public func askRecipe(_ question: String) async {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, isAskRecipeAvailable, let intelligence, let toolbox = makeAskToolbox() else { return }
        askMessages.append(AskRecipeMessage(role: .user, text: trimmed))
        let reply = await intelligence.askRecipe(trimmed, toolbox: toolbox)
        askMessages.append(
            AskRecipeMessage(
                role: .assistant,
                text: reply ?? "I couldn't answer that one. Check the ingredients and steps above."
            )
        )
    }

    public func clearAskRecipe() { askMessages = [] }
}

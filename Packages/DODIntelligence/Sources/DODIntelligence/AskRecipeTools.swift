import Foundation

#if os(iOS)
import FoundationModels

@available(iOS 26, *)
struct RecipeIngredientsTool: Tool {
    let toolbox: AskRecipeToolbox
    let name = "getIngredients"
    let description =
        "Returns this recipe's ingredient lines at the cook's current serving size. Optional keyword filters the lines."
    @Generable struct Arguments {
        @Guide(description: "Keyword to filter ingredients, or empty for all") var keyword: String
    }
    func call(arguments: Arguments) async throws -> String {
        let lines = toolbox.ingredients(matching: arguments.keyword)
        return ([toolbox.servingsLine()] + lines).joined(separator: "\n")
    }
}

@available(iOS 26, *)
struct RecipeStepsTool: Tool {
    let toolbox: AskRecipeToolbox
    let name = "getSteps"
    let description =
        "Returns recipe instruction steps. Give a step number, or a keyword such as 'refrigerate' or 'rest'."
    @Generable struct Arguments {
        @Guide(description: "1-based step number, or 0 to search by keyword") var stepNumber: Int
        @Guide(description: "Keyword to search steps; empty when stepNumber is used") var keyword: String
    }
    func call(arguments: Arguments) async throws -> String {
        if arguments.stepNumber > 0 {
            return toolbox.step(number: arguments.stepNumber) ?? "No such step."
        }
        let hits = toolbox.steps(matching: arguments.keyword)
        return hits.isEmpty ? "No matching steps." : hits.joined(separator: "\n")
    }
}

@available(iOS 26, *)
struct RecipeMakeAheadTool: Tool {
    let toolbox: AskRecipeToolbox
    let name = "getMakeAheadHints"
    let description = "Returns steps in this recipe that mention chilling, resting, cooling or freezing."
    @Generable struct Arguments {
        @Guide(description: "Always an empty string") var unused: String
    }
    func call(arguments: Arguments) async throws -> String {
        let hints = toolbox.makeAheadHints()
        return hints.isEmpty ? "The recipe says nothing about making ahead." : hints.joined(separator: "\n")
    }
}
#endif

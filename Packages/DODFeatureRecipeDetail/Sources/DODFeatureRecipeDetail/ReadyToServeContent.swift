import DODDomain
import Foundation

/// DUT-987 — last-mile doneness cues + plating tip shown before the journal sheet.
struct ReadyToServeContent: Equatable {
    let donenessCues: [String]
    let platingTip: String

    static func make(for recipe: Recipe) -> ReadyToServeContent {
        let haystack = ([recipe.title] + recipe.recipeCategory + recipe.instructions.map(\.text))
            .joined(separator: " ").lowercased()
        func has(_ words: [String]) -> Bool { words.contains(where: haystack.contains) }

        var cues: [String] = []
        if has(["bread", "loaf", "bake", "cake", "biscuit", "cobbler"]) || recipe.isDessert {
            cues = ["Golden brown on top and edges", "A toothpick or knife in the center comes out clean"]
        } else if has(["chicken", "pork", "beef", "roast", "brisket", "ribs", "steak"]) {
            cues = ["Juices run clear, not pink", "Meat is tender and pulls easily with a fork"]
        } else if has(["stew", "soup", "chili", "braise", "sauce"]) {
            cues = ["Gently bubbling, not boiling hard", "Thick enough to coat the back of a spoon"]
        } else {
            cues = ["It smells fragrant and cooked through", "Texture looks right for the dish"]
        }
        cues.append("Taste a small bite and adjust salt if needed")

        let tip: String
        if has(["bread", "loaf", "biscuit"]) {
            tip = "Rest a few minutes, then serve whole on a board with a knife and butter."
        } else if recipe.isDessert || has(["cobbler", "cake"]) {
            tip = "Serve warm in shallow bowls and add a scoop of ice cream or whipped cream on top."
        } else if has(["stew", "soup", "chili"]) {
            tip = "Ladle into warm bowls and finish with fresh herbs or a swirl of cream."
        } else {
            tip = "Wipe the plate rim clean and add a pinch of fresh herbs for color."
        }
        return ReadyToServeContent(donenessCues: cues, platingTip: tip)
    }
}

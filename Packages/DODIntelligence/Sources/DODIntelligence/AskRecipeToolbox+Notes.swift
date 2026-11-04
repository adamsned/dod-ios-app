/// DUT-1028 — pure, FoundationModels-free recipe slices for Ask-The-Recipe tools.

extension AskRecipeToolbox {
    /// Steps that mention a hold/chill/rest point, used for make-ahead answers.
    public func makeAheadHints() -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for kw in ["refrigerat", "chill", "overnight", "freez", "rest", "cool"] {
            for line in steps(matching: kw) where seen.insert(line).inserted { out.append(line) }
        }
        return Array(out.prefix(5))
    }

    /// Servings line the model must quote verbatim: "Makes 4 servings" or "Serving count not listed".
    public func servingsLine() -> String {
        guard let servings else { return "Serving count not listed" }
        return "Makes \(servings) serving\(servings == 1 ? "" : "s")"
    }
}

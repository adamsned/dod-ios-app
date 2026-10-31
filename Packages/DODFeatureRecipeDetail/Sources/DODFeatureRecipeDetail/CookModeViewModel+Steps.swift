import DODDomain

extension CookModeViewModel {

    /// DUT-168 — ingredients referenced by the step on screen (empty when none
    /// match, or in the Done state). Reads the cache built at init; never re-parses.
    public var currentStepIngredients: [RecipeIngredient] {
        guard !isFinished, stepIngredients.indices.contains(currentStepIndex) else { return [] }
        return stepIngredients[currentStepIndex]
    }
}

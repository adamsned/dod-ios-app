import DODDomain
import DODIntelligence
import Foundation

/// DUT-1978 (DUT-1009 part 5) — orchestrates photo -> ingredient names ->
/// ranked recipes. Stores the ``DODIntelligenceService`` PROTOCOL only
/// (never FoundationModels), like ``CookingHelperViewModel``.
@MainActor
@Observable
public final class FridgeFinderViewModel {
    public enum Phase: Equatable, Sendable { case idle, identifying, results, noIngredients }

    private let intelligence: (any DODIntelligenceService)?
    private let loadRecipes: @Sendable () async -> [Recipe]

    public internal(set) var phase: Phase = .idle
    /// Editable: the cook can remove a wrong guess or add a missed item.
    public internal(set) var ingredients: [String] = []
    public internal(set) var matches: [PantryMatch] = []

    public init(
        intelligence: (any DODIntelligenceService)?,
        loadRecipes: @escaping @Sendable () async -> [Recipe]
    ) {
        self.intelligence = intelligence
        self.loadRecipes = loadRecipes
    }

    public var isAvailable: Bool { intelligence?.isAvailable ?? false }
    public var supportsImageInput: Bool { intelligence?.supportsImageInput ?? false }

    private func rematch() async {
        matches = PantryMatcher.rank(recipes: await loadRecipes(), pantry: ingredients)
        phase = ingredients.isEmpty ? .noIngredients : .results
    }
}

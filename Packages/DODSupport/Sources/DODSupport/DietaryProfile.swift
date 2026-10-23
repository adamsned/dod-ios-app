import Foundation

/// Dietary pattern a user can opt into (DUT-126). Raw values are persisted.
public enum DietaryPattern: String, CaseIterable, Sendable, Hashable, Codable {
    case vegetarian, vegan, glutenFree, dairyFree, keto, lowSodium

    public var displayName: String {
        switch self {
        case .vegetarian: "Vegetarian"
        case .vegan: "Vegan"
        case .glutenFree: "Gluten-Free"
        case .dairyFree: "Dairy-Free"
        case .keto: "Keto"
        case .lowSodium: "Low-Sodium"
        }
    }
}

/// Allergen a user can flag to avoid (DUT-126). Raw values are persisted.
public enum Allergen: String, CaseIterable, Sendable, Hashable, Codable {
    case nuts, shellfish, eggs, dairy, gluten, soy, fish

    public var displayName: String {
        switch self {
        case .nuts: "Nuts"
        case .shellfish: "Shellfish"
        case .eggs: "Eggs"
        case .dairy: "Dairy"
        case .gluten: "Gluten"
        case .soy: "Soy"
        case .fish: "Fish"
        }
    }
}

public struct DietaryProfile: Sendable, Hashable, Codable {
    public var patterns: Set<DietaryPattern>
    public var allergens: Set<Allergen>
    /// Opt-in "only show recipes that fit my preferences". Off by default.
    public var onlyShowFitting: Bool

    public init(patterns: Set<DietaryPattern> = [], allergens: Set<Allergen> = [], onlyShowFitting: Bool = false) {
        self.patterns = patterns
        self.allergens = allergens
        self.onlyShowFitting = onlyShowFitting
    }

    /// True when nothing is selected. The UI shows no badges, warnings or filtering in this state.
    public var isEmpty: Bool { patterns.isEmpty && allergens.isEmpty }
}

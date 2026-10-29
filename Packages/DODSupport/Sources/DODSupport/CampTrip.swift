import Foundation

/// DUT-1000 — one planned meal on a camp trip.
public struct CampMeal: Sendable, Equatable, Codable, Identifiable {
    public let id: UUID
    /// 0-based day index within the trip.
    public let day: Int
    public let recipeTitle: String
    public let ovenTempF: Int
    public let ovenDiameterInches: Int
    public let task: CampMealTask
    /// Raw ingredient lines for the pack list.
    public let ingredients: [String]

    public init(
        id: UUID = UUID(),
        day: Int,
        recipeTitle: String,
        ovenTempF: Int,
        ovenDiameterInches: Int = 12,
        task: CampMealTask,
        ingredients: [String] = []
    ) {
        self.id = id
        self.day = day
        self.recipeTitle = recipeTitle
        self.ovenTempF = ovenTempF
        self.ovenDiameterInches = ovenDiameterInches
        self.task = task
        self.ingredients = ingredients
    }
}

/// Represents the cooking task for a camp meal.
public enum CampMealTask: String, Sendable, Codable, CaseIterable {
    case bake, roast, simmer, fry

    /// The matching ``CharcoalRecipeConverter`` task.
    public var cookTask: CharcoalRecipeConverter.CookTask {
        switch self {
        case .bake: .bake
        case .roast: .roast
        case .simmer: .simmer
        case .fry: .fry
        }
    }
}

public struct CampTrip: Sendable, Equatable, Codable {
    public var name: String
    public var nights: Int
    public var meals: [CampMeal]

    public init(name: String, nights: Int, meals: [CampMeal] = []) {
        self.name = name
        self.nights = nights
        self.meals = meals
    }

    /// Meals ordered by day, then original order (stable).
    public var sequencedMeals: [CampMeal] {
        meals.enumerated()
            .sorted { ($0.element.day, $0.offset) < ($1.element.day, $1.offset) }
            .map(\.element)
    }
}

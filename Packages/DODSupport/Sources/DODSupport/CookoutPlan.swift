import Foundation

/// DUT-965 — a hosted cookout: how many guests, and which recipes (dishes) are on the menu.
public struct CookoutPlan: Codable, Sendable, Equatable, Identifiable {
    public struct Dish: Codable, Sendable, Equatable, Identifiable {
        public let recipeID: Int
        public let title: String
        /// Servings the source recipe yields (Recipe.servings, or 4 if unknown).
        public let sourceServings: Int
        /// Style hint used later for coal math. true = baking (lid-heavy).
        public let isBaking: Bool
        /// Dutch oven diameter in inches for this dish.
        public let ovenDiameterInches: Int
        /// Minutes the dish needs on heat.
        public let cookMinutes: Int
        public var id: Int { recipeID }
        public init(
            recipeID: Int,
            title: String,
            sourceServings: Int,
            isBaking: Bool = false,
            ovenDiameterInches: Int = 12,
            cookMinutes: Int
        ) {
            self.recipeID = recipeID
            self.title = title
            self.sourceServings = max(1, sourceServings)
            self.isBaking = isBaking
            self.ovenDiameterInches = ovenDiameterInches
            self.cookMinutes = max(0, cookMinutes)
        }
    }

    public let id: UUID
    public var name: String
    public var guestCount: Int
    /// Planned mealtime.
    public var serveAt: Date
    public var dishes: [Dish]

    public init(id: UUID = UUID(), name: String, guestCount: Int, serveAt: Date, dishes: [Dish] = []) {
        self.id = id
        self.name = name
        self.guestCount = max(1, guestCount)
        self.serveAt = serveAt
        self.dishes = dishes
    }

    /// Multiplier to feed `guestCount` people from a dish. Feed to `FractionRenderer.scale`.
    public func scaleFactor(for dish: Dish) -> Double {
        Double(guestCount) / Double(dish.sourceServings)
    }

    /// Ingredient lines for `dish`, scaled to the guest count.
    public func scaledIngredients(_ lines: [String], for dish: Dish) -> [String] {
        let factor = scaleFactor(for: dish)
        return lines.map { FractionRenderer.scale($0, by: factor) }
    }
}

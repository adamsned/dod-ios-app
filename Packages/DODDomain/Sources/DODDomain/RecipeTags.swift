import Foundation

/// DUT-1022: closed-vocabulary catalog tags. Raw values are persisted and
/// compared downstream, so renaming a case is a data migration.
public enum RecipeDifficulty: String, Sendable, Hashable, Codable, CaseIterable {
    case beginner, intermediate, advanced
}

public enum RecipeTechnique: String, Sendable, Hashable, Codable, CaseIterable {
    case sear, braise, roast, bake, fry, simmer, grill, smoke, stew, breadMaking
}

public enum RecipeOccasion: String, Sendable, Hashable, Codable, CaseIterable {
    case weeknight, weekend, holiday, entertaining, campfire, breakfast, dessert
}

/// Where a tag set came from, so an auto-tag is never silently trusted
/// and a manual override can win later.
public enum RecipeTagSource: String, Sendable, Hashable, Codable {
    case auto, manual
}

public struct RecipeTags: Sendable, Hashable, Codable {
    public let difficulty: RecipeDifficulty
    public let techniques: [RecipeTechnique]
    public let occasions: [RecipeOccasion]
    public let source: RecipeTagSource

    public init(
        difficulty: RecipeDifficulty,
        techniques: [RecipeTechnique] = [],
        occasions: [RecipeOccasion] = [],
        source: RecipeTagSource = .auto
    ) {
        self.difficulty = difficulty
        self.techniques = techniques
        self.occasions = occasions
        self.source = source
    }
}

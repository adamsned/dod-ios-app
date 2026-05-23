import Foundation

/// Full recipe model. Populated in two phases:
/// 1. List fields (id, title, excerpt, image, etc.) come from the WP REST API.
/// 2. Detail fields (ingredients, instructions, times, nutrition, video) come
///    from the JSON-LD Recipe block on the rendered post page.
///
/// Spec trace: spec.md AC-4.* (recipe detail) and AC-4.11 (hybrid fetch).
public struct Recipe: Sendable, Hashable, Identifiable, Codable {

    // MARK: - List-fetch fields

    public let id: Int
    public let slug: String
    public let title: String
    public let excerpt: String
    public let canonicalURL: URL
    public let heroImage: URL?
    public let heroImageLargeURL: URL?
    public let categoryIDs: [Int]
    public let publishedAt: Date

    // MARK: - Detail-fetch fields (populated post JSON-LD parse)

    public let ingredients: [RecipeIngredient]
    public let instructions: [RecipeInstruction]
    public let prepTime: Duration?
    public let cookTime: Duration?
    public let totalTime: Duration?
    public let servings: Int?
    public let nutrition: RecipeNutrition?
    public let video: RecipeVideo?

    public init(
        id: Int,
        slug: String,
        title: String,
        excerpt: String,
        canonicalURL: URL,
        heroImage: URL? = nil,
        heroImageLargeURL: URL? = nil,
        categoryIDs: [Int] = [],
        publishedAt: Date,
        ingredients: [RecipeIngredient] = [],
        instructions: [RecipeInstruction] = [],
        prepTime: Duration? = nil,
        cookTime: Duration? = nil,
        totalTime: Duration? = nil,
        servings: Int? = nil,
        nutrition: RecipeNutrition? = nil,
        video: RecipeVideo? = nil
    ) {
        self.id = id
        self.slug = slug
        self.title = title
        self.excerpt = excerpt
        self.canonicalURL = canonicalURL
        self.heroImage = heroImage
        self.heroImageLargeURL = heroImageLargeURL
        self.categoryIDs = categoryIDs
        self.publishedAt = publishedAt
        self.ingredients = ingredients
        self.instructions = instructions
        self.prepTime = prepTime
        self.cookTime = cookTime
        self.totalTime = totalTime
        self.servings = servings
        self.nutrition = nutrition
        self.video = video
    }
}

extension Recipe {
    /// True once the JSON-LD detail parse has populated cooking content.
    public var hasDetail: Bool {
        !ingredients.isEmpty || !instructions.isEmpty
    }
}

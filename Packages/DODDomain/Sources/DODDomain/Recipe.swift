import Foundation

/// Full recipe model. Populated in two phases:
/// 1. List fields (id, title, excerpt, image, etc.) come from the WP REST API.
/// 2. Detail fields (ingredients, instructions, times, nutrition, video) come
///    from the JSON-LD Recipe block on the rendered post page.
///
/// Per US-37 / CL-63 / AC-37.2 (T-640), this type also models **articles**
/// (posts without a parseable JSON-LD `@type: Recipe` block) via the
/// ``kind`` discriminator. Article rows have:
/// - `kind == .article`
/// - empty `ingredients` + `instructions` (no JSON-LD to parse)
/// - a populated `articleBodyHTML` string (sanitized plain text extracted
///   from the rendered HTML page via ``DODSupport/ArticleBodyExtractor``)
/// - usually nil `servings`, `prepTime`, `cookTime`, `totalTime`,
///   `nutrition`, `video` — none of those are meaningful for articles.
///
/// Spec trace: spec.md AC-4.* (recipe detail), AC-4.11 (hybrid fetch),
/// US-37 / CL-63 (article path).
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

    // MARK: - Kind discriminator + article fields (US-37 / CL-63)

    /// Discriminates between WPRM/JSON-LD recipes and HTML-body articles.
    /// Defaults to `.recipe` so existing callers (Codable decoders, fixture
    /// builders, REST → domain mappers) keep producing recipe-kind rows
    /// without an explicit argument.
    public let kind: PostKind
    /// Sanitized plain-text article body. Non-nil only when `kind == .article`
    /// (populated by ``DODSupport/ArticleBodyExtractor``). Nil for recipes —
    /// recipe content lives in `ingredients` + `instructions`.
    public let articleBodyHTML: String?

    // MARK: - Editorial info fields (DUT-572 / CL-310)

    /// Course(s) from JSON-LD `recipeCategory` (e.g. "Dessert"). Empty when absent.
    public let recipeCategory: [String]
    /// Cuisine(s) from JSON-LD `recipeCuisine` (e.g. "Italian"). Empty when absent.
    public let recipeCuisine: [String]
    /// Diet(s) from JSON-LD `suitableForDiet`. Values may be schema.org URLs
    /// (e.g. `https://schema.org/LowFatDiet`) stored raw; prettifying is the UI's job.
    /// Empty when absent.
    public let suitableForDiet: [String]
    /// Author name from JSON-LD `author` (Person/Organization). Nil when absent.
    public let author: String?

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
        video: RecipeVideo? = nil,
        kind: PostKind = .recipe,
        articleBodyHTML: String? = nil,
        recipeCategory: [String] = [],
        recipeCuisine: [String] = [],
        suitableForDiet: [String] = [],
        author: String? = nil
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
        self.kind = kind
        self.articleBodyHTML = articleBodyHTML
        self.recipeCategory = recipeCategory
        self.recipeCuisine = recipeCuisine
        self.suitableForDiet = suitableForDiet
        self.author = author
    }

    // MARK: - Codable (back-compat for older payloads pre-kind)

    /// Codable keys are explicit so older on-disk payloads (e.g. cached
    /// detail blobs serialized before US-37) decode cleanly — the new
    /// `kind` and `articleBodyHTML` keys are optional with sensible
    /// defaults (`.recipe` and `nil` respectively).
    enum CodingKeys: String, CodingKey {
        case id, slug, title, excerpt, canonicalURL, heroImage, heroImageLargeURL
        case categoryIDs, publishedAt, ingredients, instructions
        case prepTime, cookTime, totalTime, servings, nutrition, video
        case kind, articleBodyHTML
        case recipeCategory, recipeCuisine, suitableForDiet, author
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.slug = try container.decode(String.self, forKey: .slug)
        self.title = try container.decode(String.self, forKey: .title)
        self.excerpt = try container.decode(String.self, forKey: .excerpt)
        self.canonicalURL = try container.decode(URL.self, forKey: .canonicalURL)
        self.heroImage = try container.decodeIfPresent(URL.self, forKey: .heroImage)
        self.heroImageLargeURL = try container.decodeIfPresent(URL.self, forKey: .heroImageLargeURL)
        self.categoryIDs = try container.decodeIfPresent([Int].self, forKey: .categoryIDs) ?? []
        self.publishedAt = try container.decode(Date.self, forKey: .publishedAt)
        self.ingredients = try container.decodeIfPresent([RecipeIngredient].self, forKey: .ingredients) ?? []
        self.instructions = try container.decodeIfPresent([RecipeInstruction].self, forKey: .instructions) ?? []
        self.prepTime = try container.decodeIfPresent(Duration.self, forKey: .prepTime)
        self.cookTime = try container.decodeIfPresent(Duration.self, forKey: .cookTime)
        self.totalTime = try container.decodeIfPresent(Duration.self, forKey: .totalTime)
        self.servings = try container.decodeIfPresent(Int.self, forKey: .servings)
        self.nutrition = try container.decodeIfPresent(RecipeNutrition.self, forKey: .nutrition)
        self.video = try container.decodeIfPresent(RecipeVideo.self, forKey: .video)
        // US-37 / CL-63: back-compat — older payloads have no `kind`,
        // default to `.recipe`. The article body is nil for recipe rows
        // by definition.
        self.kind = try container.decodeIfPresent(PostKind.self, forKey: .kind) ?? .recipe
        self.articleBodyHTML = try container.decodeIfPresent(String.self, forKey: .articleBodyHTML)
        // DUT-572 / CL-310: back-compat — older payloads predate these keys.
        // Arrays default to empty, author to nil.
        self.recipeCategory = try container.decodeIfPresent([String].self, forKey: .recipeCategory) ?? []
        self.recipeCuisine = try container.decodeIfPresent([String].self, forKey: .recipeCuisine) ?? []
        self.suitableForDiet = try container.decodeIfPresent([String].self, forKey: .suitableForDiet) ?? []
        self.author = try container.decodeIfPresent(String.self, forKey: .author)
    }
}

extension Recipe {
    /// True once the post's detail content has been populated:
    /// - For recipes: `ingredients` or `instructions` are non-empty (the
    ///   JSON-LD parse succeeded).
    /// - For articles (US-37 / CL-63 / T-640): `articleBodyHTML` is
    ///   non-empty (the article-body extraction succeeded).
    ///
    /// Used by the recipe-detail view model to decide whether the cache
    /// can serve the screen without a fresh fetch. Articles trivially
    /// have empty `ingredients` + `instructions` but DO carry their
    /// extracted body in `articleBodyHTML`, so the cache-hit path still
    /// short-circuits the network round-trip.
    public var hasDetail: Bool {
        if !ingredients.isEmpty || !instructions.isEmpty {
            return true
        }
        if kind == .article, let body = articleBodyHTML, !body.isEmpty {
            return true
        }
        return false
    }

    /// True when this post is an article (no JSON-LD Recipe; HTML body
    /// renders via ``DODFeatureRecipeDetail/ArticleDetailView``).
    /// Convenience accessor over `kind == .article` — call-sites read
    /// more naturally as a Boolean question.
    public var isArticle: Bool {
        kind == .article
    }
}

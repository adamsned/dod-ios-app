import Foundation

/// T-610 — canned data served by ``E2EStubHTTPClient`` in `-DOD_E2E_MODE=1`.
///
/// Small, hand-authored recipes turned into the exact WordPress REST + JSON-LD
/// shapes the real parsers expect, so the L5 journeys run deterministically
/// against the real code paths. Recipe ids/slugs are stable so tests can assert
/// on titles ("Garlic Butter Skillet Corn"), ingredients, and steps.
enum E2EFixtures {

    struct Recipe {
        let id: Int
        let slug: String
        let title: String
        let excerpt: String
        let yield: String
        let ingredients: [String]
        let steps: [String]
        let categoryID: Int
        let categoryName: String
    }

    static let recipes: [Recipe] = [
        Recipe(
            id: 21238,
            slug: "garlic-butter-skillet-corn",
            title: "Garlic Butter Skillet Corn",
            excerpt: "Sweet corn in garlic butter — a 15-minute skillet side.",
            yield: "4 servings",
            ingredients: ["4 cups corn kernels", "2 tablespoons butter", "2 cloves garlic, minced", "Salt to taste"],
            steps: [
                "Melt the butter in a skillet over medium heat.", "Add the garlic and corn; stir.",
                "Cook 8 minutes, season with salt, and serve.",
            ],
            categoryID: 10,
            categoryName: "Sides"
        ),
        Recipe(
            id: 683,
            slug: "dutch-oven-lasagna",
            title: "Dutch Oven Lasagna",
            excerpt: "Layered lasagna baked low-and-slow in the Dutch oven.",
            yield: "8 servings",
            ingredients: ["1 lb ground beef", "1 jar marinara", "12 lasagna noodles", "2 cups mozzarella"],
            steps: [
                "Brown the beef in the Dutch oven.", "Layer noodles, sauce, and cheese.", "Cover and bake 45 minutes.",
            ],
            categoryID: 11,
            categoryName: "Mains"
        ),
        // T-610: intentionally category 11 "Mains" — a SIBLING of Dutch Oven
        // Lasagna (also category 11) — so `posts?categories=11` returns ≥2 and
        // the recipe-detail "Related recipes" strip renders deterministically.
        Recipe(
            id: 22294,
            slug: "peach-dump-cake",
            title: "Peach Dump Cake",
            excerpt: "Dump the peaches and the cake mix, dot with butter, and bake.",
            yield: "10 servings",
            ingredients: ["2 cans sliced peaches", "1 box yellow cake mix", "1 stick butter"],
            steps: [
                "Dump the peaches into the Dutch oven.", "Top with the dry cake mix.",
                "Dot with butter and bake 40 minutes.",
            ],
            categoryID: 11,
            categoryName: "Mains"
        ),
    ]

    static func recipe(forSlug slug: String) -> Recipe? { recipes.first { $0.slug == slug } }
    static func recipe(forID id: Int) -> Recipe? { recipes.first { $0.id == id } }

    // MARK: - WP /wp/v2/posts

    static func postJSONObject(_ recipe: Recipe) -> [String: Any] {
        [
            "id": recipe.id,
            "slug": recipe.slug,
            "link": "https://www.dutchovendaddy.com/\(recipe.slug)/",
            "title": ["rendered": recipe.title],
            "excerpt": ["rendered": "<p>\(recipe.excerpt)</p>"],
            "date": "2026-05-01T12:00:00",
            "date_gmt": "2026-05-01T12:00:00",
            "featured_media": 0,
            "categories": [recipe.categoryID],
        ]
    }

    /// The posts list, honoring `search` (title contains), `categories` (id),
    /// `include`/`slug` filters so the search + category + related journeys are
    /// deterministic. No filter → every recipe.
    static func postsListJSONObjects(matching query: [String: String]) -> [[String: Any]] {
        var result = recipes
        if let search = query["search"]?.lowercased(), !search.isEmpty {
            result = result.filter { $0.title.lowercased().contains(search) }
        }
        if let categories = query["categories"], let id = Int(categories) {
            result = result.filter { $0.categoryID == id }
        }
        if let slug = query["slug"] {
            result = result.filter { $0.slug == slug }
        }
        if let include = query["include"] {
            let ids = Set(include.split(separator: ",").compactMap { Int($0) })
            if !ids.isEmpty { result = result.filter { ids.contains($0.id) } }
        }
        return result.map(postJSONObject)
    }

    // MARK: - Recipe detail HTML (JSON-LD)

    static func detailHTML(for recipe: Recipe) -> Data {
        let jsonLD: [String: Any] = [
            "@context": "https://schema.org",
            "@type": "Recipe",
            "name": recipe.title,
            "recipeYield": recipe.yield,
            "description": recipe.excerpt,
            "recipeIngredient": recipe.ingredients,
            "recipeInstructions": recipe.steps.map { ["@type": "HowToStep", "text": $0] },
        ]
        let jsonData = (try? JSONSerialization.data(withJSONObject: jsonLD)) ?? Data("{}".utf8)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
        let html = """
            <!doctype html><html><head><title>\(recipe.title)</title>
            <script type="application/ld+json">\(jsonString)</script>
            </head><body><h1>\(recipe.title)</h1><p>\(recipe.excerpt)</p></body></html>
            """
        return Data(html.utf8)
    }

    // MARK: - Comments (/wp/v2/comments)

    /// The two canned comments — both authored on post 21238 (the corn recipe).
    static let commentsJSONObjects: [[String: Any]] = [
        [
            "id": 6805, "post": 21238, "parent": 0, "author": 0, "author_name": "Maria",
            "author_url": "", "date": "2026-05-04T07:42:50", "date_gmt": "2026-05-04T13:42:50",
            "content": [
                "rendered":
                    "<p>So quick and easy — the corn stays crisp and soaks up all that garlic butter. My new favorite side.</p>"
            ],
            "link": "https://www.dutchovendaddy.com/garlic-butter-skillet-corn/#comment-6805",
            "status": "approved", "type": "comment",
        ],
        [
            "id": 6806, "post": 21238, "parent": 0, "author": 0, "author_name": "Diego",
            "author_url": "", "date": "2026-05-05T09:10:00", "date_gmt": "2026-05-05T15:10:00",
            "content": ["rendered": "<p>Added a pinch of chili flakes and it was perfect. Thanks Ned!</p>"],
            "link": "https://www.dutchovendaddy.com/garlic-butter-skillet-corn/#comment-6806",
            "status": "approved", "type": "comment",
        ],
    ]

    /// The canned comments for a given post. Only post 21238 (the corn recipe)
    /// has comments; every other post returns an empty list. Fixes the T-610
    /// stub-fidelity bug where the `/wp/v2/comments` branch ignored the `post`
    /// query and served post 21238's comments for every recipe.
    static func commentsJSONObjects(forPost postID: Int?) -> [[String: Any]] {
        postID == 21238 ? commentsJSONObjects : []
    }

    // MARK: - Categories / media / ratings

    /// One entry per DISTINCT category id, with the true recipe count for that
    /// category. (Peach Dump Cake now shares category 11 "Mains" with Dutch Oven
    /// Lasagna, so "Mains" reports count 2 — the sibling that makes the related
    /// strip render.)
    static var categoriesJSONObjects: [[String: Any]] {
        var byID: [Int: (name: String, count: Int)] = [:]
        for recipe in recipes {
            if var existing = byID[recipe.categoryID] {
                existing.count += 1
                byID[recipe.categoryID] = existing
            } else {
                byID[recipe.categoryID] = (recipe.categoryName, 1)
            }
        }
        return byID.sorted { $0.key < $1.key }
            .map { id, value in
                [
                    "id": id,
                    "name": value.name,
                    "slug": value.name.lowercased(),
                    "count": value.count,
                ]
            }
    }

    static let mediaJSONObject: [String: Any] = [
        "source_url": "https://www.dutchovendaddy.com/wp-content/e2e-hero.png",
        "media_details": ["sizes": [:]],
    ]

    /// The WPRM ratings endpoint 401/403s on the live site; mirror it so the
    /// aggregate degrades to "no rating" (REG-14) instead of erroring.
    static let ratingsForbiddenJSON = Data(
        #"{"code":"rest_forbidden","message":"Sorry, you are not allowed to do that.","data":{"status":401}}"#.utf8
    )

    /// 1×1 transparent PNG for any image request.
    static let onePixelPNG: Data =
        Data(
            base64Encoded:
                "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
        ) ?? Data()
}

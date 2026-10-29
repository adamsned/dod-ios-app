import DODDomain
import Foundation

/// Tiny fixture helpers shared across the recipe-detail test suites —
/// originally inline on `RecipeDetailViewModelTests`, now in a neutral home so
/// every regression suite can use them. Split out of
/// `FakeRecipeDetailDependencies.swift` to keep that file under the 400-line
/// lint ceiling (DUT-1340 added the collections modeling).
enum RecipeDetailTestFixtures {

    static func makeListItem(id: Int) -> RecipeListItem {
        RecipeListItem(
            id: id,
            title: "Recipe \(id)",
            excerpt: "Tasty.",
            heroImage: nil,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            totalTimeDisplay: nil
        )
    }

    static func makeComment(
        id: Int,
        postID: Int,
        body: String,
        status: RecipeComment.Status = .approved
    ) -> RecipeComment {
        RecipeComment(
            id: id,
            postID: postID,
            parentID: nil,
            authorName: "Reviewer \(id)",
            avatarURL: nil,
            dateGMT: Date(timeIntervalSince1970: 1_700_000_000),
            body: body,
            ratingValue: nil,
            status: status
        )
    }

    static func makeRecipe(
        id: Int,
        withDetail: Bool,
        categoryID: Int = 0,
        servings: Int? = nil,
        ingredients: [RecipeIngredient]? = nil,
        kind: PostKind = .recipe
    ) -> Recipe {
        let resolvedIngredients: [RecipeIngredient] =
            ingredients ?? (withDetail ? [.init(text: "salt"), .init(text: "pepper")] : [])
        return Recipe(
            id: id,
            slug: "slug-\(id)",
            title: "Recipe \(id)",
            excerpt: "Tasty.",
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/\(id)/") ?? URL(filePath: "/"),
            categoryIDs: categoryID > 0 ? [categoryID] : [],
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            ingredients: resolvedIngredients,
            instructions: withDetail ? [.init(step: 1, text: "Stir.")] : [],
            totalTime: .seconds(15 * 60),
            servings: servings,
            kind: kind
        )
    }
}

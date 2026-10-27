#if os(iOS) && canImport(UIKit)

import DODDomain
import Foundation
import SwiftUI
import UIKit
import XCTest
@testable import DODFeatureRecipeDetail

final class RecipeImageCardViewTests: XCTestCase {

    private func recipe(title: String) -> Recipe {
        Recipe(
            id: 1,
            slug: "test-recipe",
            title: title,
            excerpt: "",
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/1/") ?? URL(fileURLWithPath: "/"),
            heroImage: nil,
            heroImageLargeURL: nil,
            categoryIDs: [],
            publishedAt: Date(timeIntervalSince1970: 0),
            ingredients: [RecipeIngredient(id: UUID(), text: "Ingredient 0")],
            instructions: [RecipeInstruction(id: UUID(), step: 1, text: "Step 1 text.")],
            prepTime: nil,
            cookTime: nil,
            totalTime: nil,
            servings: 4,
            nutrition: nil,
            video: nil,
            kind: .recipe,
            articleBodyHTML: nil,
            recipeCategory: [],
            recipeCuisine: [],
            suitableForDiet: [],
            author: nil
        )
    }

    @MainActor
    private func fittedSize(title: String) -> CGSize {
        let content = ImageCardContent(recipe: recipe(title: title))
        let view = RecipeImageCardView(content: content, heroImage: nil, logo: nil, qrImage: nil)
        let controller = UIHostingController(rootView: view)
        controller.loadViewIfNeeded()
        return controller.view.sizeThatFits(in: CGSize(width: 2000, height: 3000))
    }

    @MainActor
    func testCardSizeWithoutHero() {
        XCTAssertEqual(fittedSize(title: "Pot Roast"), RecipeImageCardView.cardSize)
    }

    @MainActor
    func testCardSizeWithVeryLongTitle() {
        let title = String(repeating: "A", count: 200)
        XCTAssertEqual(fittedSize(title: title), RecipeImageCardView.cardSize)
    }
}

#endif

#if os(iOS) && canImport(UIKit)

import DODDomain
import XCTest
import SwiftUI
import UIKit
@testable import DODFeatureRecipeDetail

final class RecipeTentCardViewTests: XCTestCase {

    @MainActor
    func testRecipeTentCardViewSize() throws {
        // Build a TentCardContent (copy the Recipe construction from RecipePDFRendererTests)
        let recipe = Recipe(
            id: 42,
            slug: "test-recipe",
            title: "Test Dish Name",
            excerpt: "Test excerpt",
            canonicalURL: try XCTUnwrap(URL(string: "https://example.com/recipe")),
            publishedAt: Date()
        )
        let content = TentCardContent(recipe: recipe, hostName: "Sam")

        // Build RecipeTentCardView
        let qrImage = QRCodeImage.make(from: content.qrPayload)
        let view = RecipeTentCardView(content: content, qrImage: qrImage)

        // Wrap it in UIHostingController and assert size
        let controller = UIHostingController(rootView: view)
        controller.loadViewIfNeeded()

        let size = controller.view.sizeThatFits(CGSize(width: 1000, height: 1000))
        XCTAssertEqual(size, RecipeTentCardView.cardSize)
    }
}

#endif

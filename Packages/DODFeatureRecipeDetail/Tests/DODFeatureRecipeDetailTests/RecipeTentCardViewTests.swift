#if os(iOS) && canImport(UIKit)

import XCTest
import SwiftUI
import UIKit
@testable import DODFeatureRecipeDetail

final class RecipeTentCardViewTests: XCTestCase {

    @MainActor
    func testRecipeTentCardViewSize() throws {
        // Build a TentCardContent (copy the Recipe construction from RecipePDFRendererTests)
        let content = TentCardContent(
            dishName: "Test Dish Name",
            byline: "Test Byline",
            qrPayload: "https://example.com/test"
        )

        // Build RecipeTentCardView
        let qrImage = QRCodeImage.make(from: content.qrPayload)
        let view = RecipeTentCardView(content: content, qrImage: qrImage)

        // Wrap it in UIHostingController and assert size
        let controller = UIHostingController(rootView: view)
        controller.loadViewIfNeeded()

        let size = controller.view.sizeThatFits(in: CGSize(width: 1000, height: 1000))
        XCTAssertEqual(size, RecipeTentCardView.cardSize)
    }
}

#endif

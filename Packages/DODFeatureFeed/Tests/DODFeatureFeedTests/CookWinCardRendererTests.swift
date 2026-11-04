import Foundation
import SwiftUI
import Testing

@testable import DODFeatureFeed
@testable import DODSupport

@Suite
struct CookWinCardRendererTests {
    @MainActor
    func rendersNonEmptyPNG() throws {
        let entry = CookLogEntry(
            id: UUID(),
            recipeID: 1,
            recipeTitle: "Lasagna",
            cookedAt: Date(),
            note: "A delicious lasagna recipe"
        )

        let data = try #require(
            CookWinCardRenderer.pngData(content: CookWinCardContent(entry: entry), photo: nil, scale: 1)
        )
        #expect(data.prefix(8) == Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]))
    }

    @MainActor
    func shareItemsHaveDistinctIDs() throws {
        let item1 = CookWinShareItem(pngData: Data(), caption: "Caption 1")
        let item2 = CookWinShareItem(pngData: Data(), caption: "Caption 2")

        #expect(item1.id != item2.id)
    }
}

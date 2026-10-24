#if canImport(UIKit)
import Foundation
import SwiftUI
import Testing

@testable import DODFeatureFeed

@MainActor
@Suite struct CookoutRecapRendererTests {
    @Test func fileNameIsStable() {
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        #expect(CookoutRecapRenderer.fileName(for: day) == CookoutRecapRenderer.fileName(for: day))
        #expect(CookoutRecapRenderer.fileName(for: day).hasSuffix(".png"))
    }

    @Test func rendersNonEmptyPNG() {
        let card = CookoutRecapCard(
            headline: "Sunday cookout — 2 dishes",
            dishTitles: ["Chili", "Cornbread"],
            averageRatingText: "4.0",
            cover: nil
        )
        let data = CookoutRecapRenderer.pngData(card)
        #expect(data != nil)
        #expect(data.map { Array($0.prefix(4)) } == [0x89, 0x50, 0x4E, 0x47])
    }
}
#endif

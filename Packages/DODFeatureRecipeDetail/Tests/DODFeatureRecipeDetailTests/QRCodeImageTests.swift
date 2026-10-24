#if os(iOS) && canImport(UIKit)
import Testing
import UIKit

@testable import DODFeatureRecipeDetail

/// DUT-977 — the tent-card QR generator.
@Suite("QRCodeImage")
struct QRCodeImageTests {

    @Test func makeReturnsSquareNonEmptyImage() throws {
        let image = try #require(QRCodeImage.make(from: "dod://recipe/42"))
        #expect(image.size.width > 0)
        #expect(image.size.width == image.size.height)
    }

    @Test func largerScaleGivesLargerImage() throws {
        let small = try #require(QRCodeImage.make(from: "dod://recipe/42", scale: 5))
        let large = try #require(QRCodeImage.make(from: "dod://recipe/42", scale: 20))
        #expect(large.size.width > small.size.width)
    }
}
#endif

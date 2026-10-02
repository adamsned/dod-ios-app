#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import UIKit
import XCTest

@testable import DODDesignSystem

/// DUT-1384 — L4 regression net for SQUARE hero photos in the Latest widgets.
///
/// Every hero photo on dutchovendaddy.com is square. The other widget suites
/// render with `heroImageURL: nil` (the gradient placeholder), which has no
/// intrinsic size and so squishes politely — that hid the real bug, where a
/// square `.scaledToFill()` photo claimed its full width as a minimum height and
/// pushed the Large card's title off the bottom edge. These tests render a real
/// square image (written to a temp file and loaded through the same synchronous
/// `file://` path the widget uses) so a regression shows up as a diff.
final class WidgetSquarePhotoSnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        isRecording = false
    }

    /// A 1030×1030 two-tone image, matching the site's square hero size.
    private static let squarePhotoURL: URL = {
        let size = CGSize(width: 1030, height: 1030)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(red: 0.42, green: 0.30, blue: 0.20, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor(red: 0.86, green: 0.70, blue: 0.40, alpha: 1).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 165, y: 165, width: 700, height: 700))
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("dut1384-square-hero.png")
        try? image.pngData()?.write(to: url)
        return url
    }()

    private static let article = WidgetCard.Content(
        title: "Best Dutch Oven For Every Budget: 7 Pots I Actually Cook In",
        excerpt: "The best Dutch oven for every budget, from a cook who owns all seven.",
        heroImageURL: squarePhotoURL,
        eyebrow: "Latest Article",
        isArticle: true
    )

    private static let recipe = WidgetCard.Content(
        title: "Brown Butter Sage Gnocchi (Crispy Cast Iron Recipe)",
        excerpt: "Crispy brown butter sage gnocchi seared in a cast iron skillet with nutty browned butter.",
        heroImageURL: squarePhotoURL,
        totalTimeDisplay: "30 min",
        eyebrow: "Latest Recipe"
    )

    /// `testName` is threaded through so each test gets its own reference PNG
    /// (SnapshotTesting names the file after the CALLING function by default,
    /// which would otherwise be this helper for all three tests).
    private func assertWidget(
        _ view: some View,
        width: CGFloat,
        height: CGFloat,
        testName: String = #function
    ) {
        assertSnapshot(
            of: view.frame(width: width, height: height).background(DODColor.surfaceElevated),
            as: .image(precision: 0.98, perceptualPrecision: 0.97, layout: .fixed(width: width, height: height)),
            record: .missing,
            testName: testName
        )
    }

    /// Large article: eyebrow + the FULL title in the bottom band (no excerpt).
    func test_featuredLarge_squarePhoto_article() {
        assertWidget(WidgetCard.FeaturedLarge(content: Self.article), width: 364, height: 382)
    }

    /// Large recipe: eyebrow + full title + 2-line excerpt + time chip, all visible.
    func test_featuredLarge_squarePhoto_recipe() {
        assertWidget(WidgetCard.FeaturedLarge(content: Self.recipe), width: 364, height: 382)
    }

    /// Small recipe: centred title, eyebrow top-left, time badge bottom-right.
    func test_featuredSmall_squarePhoto_recipe() {
        assertWidget(WidgetCard.Small(content: Self.recipe), width: 158, height: 158)
    }
}
#endif

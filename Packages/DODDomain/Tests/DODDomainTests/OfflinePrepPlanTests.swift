import Foundation
import XCTest

@testable import DODDomain

final class OfflinePrepPlanTests: XCTestCase {
    func testLargeThenSmallThenEquipment() {
        let large = URL(string: "https://example.com/large.jpg")!
        let small = URL(string: "https://example.com/small.jpg")!
        let equipmentURL = URL(string: "https://example.com/equipment.jpg")!

        let recipe = Recipe(
            id: 1,
            slug: "s",
            title: "t",
            excerpt: "e",
            canonicalURL: URL(string: "https://example.com/r")!,
            heroImage: small,
            heroImageLargeURL: large,
            publishedAt: Date()
        )

        let equipment = [Equipment(name: "test", imageURL: equipmentURL)]

        let plan = OfflinePrepPlan(recipe: recipe, equipment: equipment)

        XCTAssertEqual(plan.imageURLs, [large, small, equipmentURL])
    }

    func testDuplicatesCollapse() {
        let large = URL(string: "https://example.com/large.jpg")!

        let recipe = Recipe(
            id: 1,
            slug: "s",
            title: "t",
            excerpt: "e",
            canonicalURL: URL(string: "https://example.com/r")!,
            heroImage: large,
            heroImageLargeURL: large,
            publishedAt: Date()
        )

        let equipment = [Equipment(name: "test1", imageURL: large), Equipment(name: "test2", imageURL: large)]

        let plan = OfflinePrepPlan(recipe: recipe, equipment: equipment)

        XCTAssertEqual(plan.imageURLs, [large])
    }

    func testNilsAreSkipped() {
        let recipe = Recipe(
            id: 1,
            slug: "s",
            title: "t",
            excerpt: "e",
            canonicalURL: URL(string: "https://example.com/r")!,
            heroImage: nil,
            heroImageLargeURL: nil,
            publishedAt: Date()
        )

        let equipment = [Equipment(name: "x")]

        let plan = OfflinePrepPlan(recipe: recipe, equipment: equipment)

        XCTAssertEqual(plan.imageURLs, [])
    }
}

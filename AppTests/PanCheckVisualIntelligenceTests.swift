import DODSupport
import XCTest

@testable import DODApp

@available(iOS 26.0, *)
final class PanCheckVisualIntelligenceTests: XCTestCase {
    func testKnownIdMapsToVerdict() {
        XCTAssertEqual(PanCheckEntity(id: "rustOrCarbon").verdict, .rustOrCarbon)
    }

    func testUnknownIdFallsBackToUnclear() {
        XCTAssertEqual(PanCheckEntity(id: "banana").verdict, .unclear)
    }

    func testQueryResolvesIdentifiers() async throws {
        let found = try await PanCheckQuery().entities(for: ["wellSeasoned"])
        XCTAssertEqual(found.count, 1)
    }

    func testIntentExposesTargetVerdict() {
        var intent = OpenPanCheckIntent()
        intent.target = PanCheckEntity(id: "wellSeasoned")
        XCTAssertEqual(intent.target.verdict, .wellSeasoned)
    }
}

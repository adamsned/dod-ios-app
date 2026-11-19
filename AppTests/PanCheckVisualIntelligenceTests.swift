import CoreVideo
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

    func testCGImageConversionFromPixelBuffer() {
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, 8, 8, kCVPixelFormatType_32BGRA, nil, &buffer)
        guard let buffer else { return XCTFail("no buffer") }
        let image = PanCheckQuery.cgImage(from: buffer)
        XCTAssertEqual(image?.width, 8)
    }
}

import DODSupport
import Vision
import XCTest

@testable import DODApp

final class PanCheckClassifierTests: XCTestCase {

    func testVisionPanCheckClassifierDoesNotCrash() async throws {
        // Create a simple 64x64 solid-color CGImage
        let width = 64
        let height = 64
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue

        guard
            let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            )
        else {
            XCTFail("Failed to create CGContext")
            return
        }

        // Fill with white color
        context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        guard let cgImage = context.makeImage() else {
            XCTFail("Failed to create CGImage")
            return
        }

        // Test that the classifier doesn't crash and returns a verdict
        let classifier = VisionPanCheckClassifier()
        let verdict = await classifier.verdict(for: cgImage)

        // Should not be nil and should not return rustOrCarbon for white image
        XCTAssertNotNil(verdict, "Verdict should not be nil")

        // The specific verdict may vary by OS, but it shouldn't crash
        // and shouldn't be .rustOrCarbon for a solid white image (which shouldn't be classified as rust or carbon)
        XCTAssertFalse(
            verdict == PanCheck.Verdict.rustOrCarbon,
            "White image should not be classified as rust or carbon"
        )
    }
}

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest

@testable import DODDesignSystem

/// DUT-251: the decode-time downsampler is pure ImageIO/CoreGraphics, so it runs
/// on the cross-platform `swift test` slice (no UIKit needed).
final class ImageDownsamplerTests: XCTestCase {

    /// A large source (1600px longest edge) is downsampled to the 1200px ceiling.
    func testDownsamplesLargeImageToCeiling() throws {
        let data = try makePNG(width: 1200, height: 1600)
        let out = try XCTUnwrap(ImageDownsampler.downsample(data: data))
        XCTAssertLessThanOrEqual(max(out.width, out.height), ImageDownsampler.maxPixelSize)
        // Aspect ratio (3:4) preserved: the shorter edge scales proportionally.
        XCTAssertEqual(out.width, 900, accuracy: 2)
        XCTAssertEqual(out.height, 1200, accuracy: 2)
    }

    /// A custom, smaller max pixel size is honored.
    func testHonorsCustomMaxPixelSize() throws {
        let data = try makePNG(width: 1000, height: 1000)
        let out = try XCTUnwrap(ImageDownsampler.downsample(data: data, maxPixelSize: 140))
        XCTAssertLessThanOrEqual(max(out.width, out.height), 140)
    }

    /// ImageIO does not upscale: a source already under the ceiling decodes at
    /// its native size.
    func testDoesNotUpscaleSmallImage() throws {
        let data = try makePNG(width: 200, height: 150)
        let out = try XCTUnwrap(ImageDownsampler.downsample(data: data))
        XCTAssertEqual(out.width, 200)
        XCTAssertEqual(out.height, 150)
    }

    /// Non-image bytes decode to nil (caller falls back).
    func testReturnsNilForNonImageData() {
        let junk = Data("not an image".utf8)
        XCTAssertNil(ImageDownsampler.downsample(data: junk))
    }

    /// Decoded byte cost is width * height * 4 (RGBA), clamped to >= 1.
    func testDecodedByteCost() {
        XCTAssertEqual(ImageDownsampler.decodedByteCost(width: 100, height: 50), 100 * 50 * 4)
        XCTAssertEqual(ImageDownsampler.decodedByteCost(width: 0, height: 0), 4)
    }

    // MARK: - Helpers

    /// Render a solid-color PNG of the given pixel dimensions.
    private func makePNG(width: Int, height: Int) throws -> Data {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = try XCTUnwrap(
            CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
        context.setFillColor(CGColor(red: 0.5, green: 0.3, blue: 0.1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let cgImage = try XCTUnwrap(context.makeImage())

        let mutableData = NSMutableData()
        let destination = try XCTUnwrap(
            CGImageDestinationCreateWithData(mutableData, UTType.png.identifier as CFString, 1, nil)
        )
        CGImageDestinationAddImage(destination, cgImage, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return mutableData as Data
    }
}

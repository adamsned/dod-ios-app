import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

@testable import DODFeatureFeed

/// DUT-588 — the Cooking Journal thumbnail loader must downsample off the main
/// thread and cache by photo id, so a power user's 50–200 full-res cook photos
/// no longer spike memory / hitch the main thread on open.
///
/// On the cross-platform `swift test` slice `DODImage` is a `CGImage`, so these
/// assert the downsample seam and the id-cache directly (no UIKit / SwiftUI
/// host). The seams (`loadData`, `downsample`) are injected: a byte provider
/// stands in for `CookPhotoStore` and a decode-count spy proves the cache
/// prevents re-decodes.
@MainActor
@Suite("Cook journal thumbnail loader (DUT-588)")
struct CookThumbnailLoaderTests {

    /// A full-res source is downsampled to a thumbnail no larger than the target
    /// max pixel on its longest edge — not the source's full pixel dimensions.
    @Test func downsamplesToAtMostTargetPixelSize() async throws {
        let bytes = try makePNG(width: 1200, height: 1600)
        let loader = CookThumbnailLoader(maxPixel: 168, loadData: { _ in bytes })

        await loader.loadThumbnail(id: "photo-a")

        let image = try #require(loader.cachedImage(for: "photo-a"))
        #expect(max(image.width, image.height) <= 168)
        // Aspect ratio (3:4) preserved, so nothing is stretched.
        #expect(image.width < image.height)
    }

    /// Scrolling the same row twice decodes ONCE: the second `loadThumbnail`
    /// call hits the id-cache and never re-reads or re-decodes. This is the core
    /// jank/memory guard.
    @Test func cachesByIDSoRepeatLoadsDecodeOnce() async throws {
        let bytes = try makePNG(width: 800, height: 800)
        let decodeCount = DecodeCounter()
        let loader = CookThumbnailLoader(
            maxPixel: 168,
            loadData: { _ in bytes },
            downsample: { data, maxPixel in
                decodeCount.increment()
                return CookThumbnailLoader.defaultDownsample(data, maxPixel)
            }
        )

        await loader.loadThumbnail(id: "same-row")
        await loader.loadThumbnail(id: "same-row")

        #expect(decodeCount.value == 1)
        #expect(loader.cachedImage(for: "same-row") != nil)
    }

    /// Two distinct photos each decode once and cache under their own id.
    @Test func distinctIDsEachDecodeAndCacheSeparately() async throws {
        let bytes = try makePNG(width: 400, height: 400)
        let decodeCount = DecodeCounter()
        let loader = CookThumbnailLoader(
            maxPixel: 168,
            loadData: { _ in bytes },
            downsample: { data, maxPixel in
                decodeCount.increment()
                return CookThumbnailLoader.defaultDownsample(data, maxPixel)
            }
        )

        await loader.loadThumbnail(id: "row-1")
        await loader.loadThumbnail(id: "row-2")

        #expect(decodeCount.value == 2)
        #expect(loader.cachedImage(for: "row-1") != nil)
        #expect(loader.cachedImage(for: "row-2") != nil)
    }

    /// A missing photo file (loader's byte provider returns nil, as
    /// `CookPhotoStore.data(forID:)` does for a deleted file) yields no cached
    /// image — the row falls back to its placeholder — and never crashes.
    @Test func missingPhotoYieldsPlaceholderNotCrash() async {
        let loader = CookThumbnailLoader(maxPixel: 168, loadData: { _ in nil })

        await loader.loadThumbnail(id: "gone")

        #expect(loader.cachedImage(for: "gone") == nil)
    }

    /// Undecodable bytes (a corrupt / non-image file on disk) also resolve to no
    /// cached image rather than crashing.
    @Test func undecodableBytesYieldPlaceholderNotCrash() async {
        let junk = Data("not an image".utf8)
        let loader = CookThumbnailLoader(maxPixel: 168, loadData: { _ in junk })

        await loader.loadThumbnail(id: "corrupt")

        #expect(loader.cachedImage(for: "corrupt") == nil)
    }

    // MARK: - Helpers

    /// A tiny thread-safe counter so the injected downsample spy can be mutated
    /// from a detached task and read back on the main actor.
    private final class DecodeCounter: @unchecked Sendable {
        private let lock = NSLock()
        private var count = 0
        func increment() {
            lock.lock()
            count += 1
            lock.unlock()
        }
        var value: Int {
            lock.lock()
            defer { lock.unlock() }
            return count
        }
    }

    /// Render a solid-color PNG of the given pixel dimensions (mirrors the
    /// DUT-251 `ImageDownsamplerTests` helper).
    private func makePNG(width: Int, height: Int) throws -> Data {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = try #require(
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
        let cgImage = try #require(context.makeImage())

        let mutableData = NSMutableData()
        let destination = try #require(
            CGImageDestinationCreateWithData(mutableData, UTType.png.identifier as CFString, 1, nil)
        )
        CGImageDestinationAddImage(destination, cgImage, nil)
        #expect(CGImageDestinationFinalize(destination))
        return mutableData as Data
    }
}

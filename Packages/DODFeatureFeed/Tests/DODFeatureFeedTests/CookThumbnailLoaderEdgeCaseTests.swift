import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

@testable import DODFeatureFeed

/// DUT-588 — edge-case gaps in `CookThumbnailLoader` coverage: direct static
/// `imageIODownsample` tests, unknown-id and in-flight cache lookups, retry
/// after failure, concurrent in-flight idempotency. These complement the
/// `CookThumbnailLoaderTests` happy-path suite.
@MainActor
@Suite("Cook thumbnail loader edge cases (DUT-588)")
struct CookThumbnailLoaderEdgeCaseTests {

    /// Empty Data to `imageIODownsample` returns nil without crashing — the
    /// loader falls back to a placeholder, never panics.
    @Test func imageIODownsampleEmptyDataReturnsNil() {
        let result = CookThumbnailLoader.imageIODownsample(data: Data(), maxPixel: 100)
        #expect(result == nil)
    }

    /// `imageIODownsample` with `maxPixel <= 0` is safely guarded by `max(1, maxPixel)`:
    /// the function treats it as maxPixel=1 and returns a valid CGImage.
    @Test func imageIODownsampleMaxPixelZeroReturnsValidImage() throws {
        let bytes = try makePNG(width: 200, height: 200)
        let result = CookThumbnailLoader.imageIODownsample(data: bytes, maxPixel: 0)
        #expect(result != nil)
    }

    /// `imageIODownsample` with `maxPixel` larger than the source image still
    /// returns a valid CGImage (just not actually downsampled).
    @Test func imageIODownsampleMaxPixelLargerThanSourceReturnsValid() throws {
        let bytes = try makePNG(width: 50, height: 50)
        let result = CookThumbnailLoader.imageIODownsample(data: bytes, maxPixel: 500)
        #expect(result != nil)
    }

    /// Junk data (not a valid image format) to `imageIODownsample` returns nil
    /// instead of crashing — corrupt / deleted files on disk never panic the loader.
    @Test func imageIODownsampleJunkDataReturnsNil() {
        let junk = Data([0x00, 0xFF, 0xFE, 0xFD])
        let result = CookThumbnailLoader.imageIODownsample(data: junk, maxPixel: 100)
        #expect(result == nil)
    }

    /// `cachedImage(for:)` on an unknown id returns nil — the cache has no entry
    /// because the id has never been loaded.
    @Test func cachedImageUnknownIDReturnsNil() {
        let loader = CookThumbnailLoader(maxPixel: 168, loadData: { _ in nil })
        #expect(loader.cachedImage(for: "never-loaded") == nil)
    }

    /// `cachedImage(for:)` queried while the id is in-flight (load hasn't
    /// completed yet) returns nil. Once the async load finishes, the next query
    /// returns the cached image.
    ///
    /// A real `bytes`-sized decode is too fast to reliably observe mid-flight —
    /// polling after a fixed sleep raced the decode and lost every time on this
    /// hardware (confirmed 5/5 failures during backstop review: the image was
    /// already cached by the time the poll ran). Injecting a deliberately-slow
    /// `downsample` closure makes the in-flight window deterministic instead of
    /// racing real decode speed.
    @Test func cachedImageInFlightLoadReturnsNilThenValue() async throws {
        let bytes = try makePNG(width: 100, height: 100)
        let loader = CookThumbnailLoader(
            maxPixel: 168,
            loadData: { _ in bytes },
            downsample: { data, maxPixel in
                Thread.sleep(forTimeInterval: 0.05)
                return CookThumbnailLoader.defaultDownsample(data, maxPixel)
            }
        )

        // Kick off the load without awaiting yet.
        let loadTask = Task {
            await loader.loadThumbnail(id: "in-flight")
        }

        // Poll well before the artificial 50ms decode delay elapses.
        try await Task.sleep(nanoseconds: 10_000_000)  // 10ms
        let inFlightResult = loader.cachedImage(for: "in-flight")
        #expect(inFlightResult == nil)

        // Wait for the (deliberately slow) load to finish.
        await loadTask.value
        let cachedResult = loader.cachedImage(for: "in-flight")
        #expect(cachedResult != nil)
    }

    /// Retry after failure: first `loadThumbnail` with missing data (returns nil),
    /// so `cachedImage` is also nil. Then a second injection with valid bytes and
    /// a second `loadThumbnail` call succeeds and caches the image.
    @Test func retryAfterFailureDecodeOnRetry() async throws {
        let bytes = try makePNG(width: 100, height: 100)
        let dataAvailable = DataAvailabilityFlag()

        let loader = CookThumbnailLoader(
            maxPixel: 168,
            loadData: { _ in dataAvailable.isSet ? bytes : nil },
            downsample: CookThumbnailLoader.defaultDownsample
        )

        // First load: data unavailable, so cache miss.
        await loader.loadThumbnail(id: "retry-test")
        #expect(loader.cachedImage(for: "retry-test") == nil)

        // Simulate data becoming available (e.g., photo saved after sync).
        dataAvailable.set()

        // Second load for the same id should attempt decode (in-flight guard was
        // cleared on first miss).
        await loader.loadThumbnail(id: "retry-test")
        #expect(loader.cachedImage(for: "retry-test") != nil)
    }

    /// Concurrent in-flight loads for the same id only decode once: the in-flight
    /// guard prevents the second concurrent call from triggering a redundant
    /// read + decode.
    @Test func concurrentInFlightLoadsDecodeOnce() async throws {
        let bytes = try makePNG(width: 100, height: 100)
        let decodeCounter = DecodeCounter()

        let loader = CookThumbnailLoader(
            maxPixel: 168,
            loadData: { _ in bytes },
            downsample: { data, maxPixel in
                decodeCounter.increment()
                return CookThumbnailLoader.defaultDownsample(data, maxPixel)
            }
        )

        // Fire off two concurrent loads for the same id.
        async let first = loader.loadThumbnail(id: "concurrent")
        async let second = loader.loadThumbnail(id: "concurrent")
        _ = await (first, second)

        #expect(decodeCounter.value == 1)
        #expect(loader.cachedImage(for: "concurrent") != nil)
    }

    // MARK: - Helpers

    /// Thread-safe mutable flag — `retryAfterFailureDecodeOnRetry` mutates this
    /// from the test body after it's captured by the `@Sendable loadData`
    /// closure, so a bare `var` fails Swift 6's [#SendableClosureCaptures]
    /// check; this box gives the mutation a lock instead.
    private final class DataAvailabilityFlag: @unchecked Sendable {
        private let lock = NSLock()
        private var value = false
        func set() {
            lock.lock()
            value = true
            lock.unlock()
        }
        var isSet: Bool {
            lock.lock()
            defer { lock.unlock() }
            return value
        }
    }

    /// Thread-safe decode counter (same as in CookThumbnailLoaderTests).
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

    /// Render a solid-color PNG of the given pixel dimensions.
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
            CGImageDestinationCreateWithData(
                mutableData,
                UTType.png.identifier as CFString,
                1,
                nil
            )
        )
        CGImageDestinationAddImage(destination, cgImage, nil)
        #expect(CGImageDestinationFinalize(destination))
        return mutableData as Data
    }
}

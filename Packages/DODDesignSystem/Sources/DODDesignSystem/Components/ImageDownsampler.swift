import CoreGraphics
import Foundation
import ImageIO

/// DUT-251: decode-time downsampling for recipe images.
///
/// `ReliableImage` previously decoded every hero via `UIImage(data:)`, whose
/// backing store is sized to the *source* pixels — WP heroes (esp.
/// `heroImageLargeURL`) are typically 1024px+ wide, so a 140pt feed thumbnail
/// held a multi-MB full-res bitmap. This downsampler decodes via ImageIO's
/// thumbnail path (`CGImageSourceCreateThumbnailAtIndex`) bounded to a max
/// longest-edge pixel size, so the decoded bitmap is sized to the display, not
/// the source.
///
/// The logic is UIKit-free (`CGImageSource` + `CGImage`), so it is exercised by
/// the cross-platform `swift test` slice; `ReliableImage` wraps the result in a
/// `UIImage` on iOS.
enum ImageDownsampler {

    /// Longest-edge ceiling (in pixels) for a decoded recipe image.
    ///
    /// The largest on-screen render is the recipe-detail hero at 320pt; at the
    /// 3× Retina scale that is 960px, so a 1200px cap covers every card / hero /
    /// strip render at full Retina crispness while keeping the decoded backing
    /// store bounded. Images already smaller than the cap decode at their native
    /// size (ImageIO does not upscale).
    static let maxPixelSize = 1200

    /// Downsample `data` to a `CGImage` whose longest edge is `<= maxPixelSize`.
    ///
    /// Uses `kCGImageSourceShouldCacheImmediately` so the decode happens here
    /// (off the main thread, on the loader's task) rather than lazily on first
    /// draw, and `kCGImageSourceCreateThumbnailWithTransform` so EXIF-rotated
    /// source images come out upright. `kCGImageSourceThumbnailMaxPixelSize`
    /// bounds the LONGEST edge, preserving aspect ratio. Returns `nil` when the
    /// bytes are not a decodable image.
    static func downsample(data: Data, maxPixelSize: Int = ImageDownsampler.maxPixelSize) -> CGImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }
        let options =
            [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: max(1, maxPixelSize),
            ] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
    }

    /// Estimated decoded byte cost of a `CGImage` (4 bytes per pixel, RGBA).
    /// Used as the `NSCache` per-entry cost so the in-memory cache is bounded by
    /// decoded-pixel memory, not object count.
    static func decodedByteCost(width: Int, height: Int) -> Int {
        max(1, width) * max(1, height) * 4
    }
}

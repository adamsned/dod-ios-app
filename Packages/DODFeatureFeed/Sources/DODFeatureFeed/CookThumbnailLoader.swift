import CoreGraphics
import DODPersistence
import Foundation
import ImageIO

#if canImport(UIKit)
import UIKit
#endif

/// DUT-588 — off-main, downsampled, id-cached thumbnail loader for the Cooking
/// Journal rows.
///
/// The journal previously decoded the FULL-resolution JPEG (saved at
/// `jpegData(compressionQuality: 0.85)`, full phone-camera pixel dims) with
/// `UIImage(data:)` synchronously in the view body, once per row, just to draw a
/// 56×56 thumbnail. With a power user's 50–200 logged cooks that meant a
/// multi-hundred-MB spike + main-thread hitch on open (OOM risk).
///
/// This loader fixes all three axes the ticket calls out that live on the
/// read/decode path:
///
/// 1. **Downsample** via ``ImageDownsampler`` (ImageIO's
///    `CGImageSourceCreateThumbnailAtIndex`, the same path DUT-251 / DUT-467
///    use) so the decoded bitmap is sized to the 56pt thumbnail, not the source.
/// 2. **Off the main thread** — the disk read + decode run on a detached task,
///    so scrolling never blocks the main actor.
/// 3. **Cached by photo id** — a decoded thumbnail is memoized, so re-appearing
///    rows (scroll up, scroll back down) never re-read or re-decode.
///
/// The photo STORAGE format is untouched (photos stay full-res on disk); only
/// this read/decode path changed. A missing / undecodable file resolves to
/// `nil` (never a crash), and the row falls back to its flame placeholder.
///
/// `@Observable` + `@MainActor` so a SwiftUI row can `.task`-load and re-render
/// when a cached image lands. Seams (`loadData`, `downsample`) are injected so
/// the loader is testable without a live store or a SwiftUI host.
@MainActor
@Observable
public final class CookThumbnailLoader {

    /// The 56×56 thumbnail is drawn at up to 3× Retina, so a 168px longest-edge
    /// cap keeps the decoded bitmap crisp while bounding its backing store to a
    /// few KB per row instead of a full-res JPEG.
    public nonisolated static let thumbnailMaxPixel = 168

    /// Decoded, downsampled thumbnails keyed by photo id. A hit skips both the
    /// disk read and the decode, so a row that scrolls off and back on never
    /// re-decodes.
    private var cache: [String: DODImage] = [:]

    /// Ids with an in-flight or resolved load, so concurrent `.task`s for the
    /// same row don't each kick off a redundant read+decode.
    private var inFlight: Set<String> = []

    private let maxPixel: Int
    private let loadData: @Sendable (String) -> Data?
    private let downsample: @Sendable (Data, Int) -> DODImage?

    /// - Parameters:
    ///   - maxPixel: longest-edge pixel cap for the downsampled thumbnail.
    ///   - loadData: raw bytes for a photo id, or nil when the file is gone.
    ///     Defaults to reading through ``CookPhotoStore``.
    ///   - downsample: bytes + max pixel size → a downsampled image, or nil on a
    ///     decode failure. Defaults to the ImageIO ``ImageDownsampler``.
    public init(
        maxPixel: Int = CookThumbnailLoader.thumbnailMaxPixel,
        loadData: (@Sendable (String) -> Data?)? = nil,
        downsample: @escaping @Sendable (Data, Int) -> DODImage? = CookThumbnailLoader.defaultDownsample
    ) {
        self.maxPixel = maxPixel
        if let loadData {
            self.loadData = loadData
        } else {
            let store = CookPhotoStore()
            self.loadData = { store.data(forID: $0) }
        }
        self.downsample = downsample
    }

    /// A cached thumbnail for `id`, if one has already been decoded.
    public func cachedImage(for id: String) -> DODImage? { cache[id] }

    /// Ensure a thumbnail for `id` is decoded and cached, reading + decoding OFF
    /// the main thread. Idempotent: a second call for an id that's cached or
    /// in-flight returns immediately, so scrolling the same row twice decodes
    /// once. Resolving to `nil` (missing / undecodable file) is a valid outcome
    /// — the row keeps its placeholder.
    public func loadThumbnail(id: String) async {
        if cache[id] != nil || inFlight.contains(id) { return }
        inFlight.insert(id)
        let maxPixel = self.maxPixel
        let loadData = self.loadData
        let downsample = self.downsample
        let image = await Task.detached(priority: .utility) { () -> DODImage? in
            guard let data = loadData(id) else { return nil }
            return downsample(data, maxPixel)
        }.value
        if let image {
            cache[id] = image
        } else {
            // Nothing to cache, but drop the in-flight guard so a later retry
            // (e.g. a photo added after the first miss) can try again.
            inFlight.remove(id)
        }
    }

    /// Default downsampler: ImageIO's thumbnail decode
    /// (`CGImageSourceCreateThumbnailAtIndex`) bounded to `maxPixel` on the
    /// longest edge, wrapped as a `DODImage`. Mirrors the DUT-251
    /// `ImageDownsampler` / DUT-467 `SpotlightIndexer` approach — decoding at
    /// thumbnail scale never materializes the full-res bitmap in RAM. Kept local
    /// because DODDesignSystem's `ImageDownsampler` is internal to a locked lane.
    /// Returns nil when the bytes aren't a decodable image, so a deleted /
    /// corrupt file yields the placeholder, not a crash.
    public nonisolated static let defaultDownsample: @Sendable (Data, Int) -> DODImage? = { data, maxPixel in
        guard let cgImage = imageIODownsample(data: data, maxPixel: maxPixel) else { return nil }
        #if canImport(UIKit)
        return UIImage(cgImage: cgImage)
        #else
        return cgImage
        #endif
    }

    /// Decode `data` to a `CGImage` whose longest edge is `<= maxPixel` via
    /// ImageIO's thumbnail path. `kCGImageSourceShouldCacheImmediately` forces
    /// the decode here (on the loader's detached task) rather than lazily on
    /// first draw; `kCGImageSourceCreateThumbnailWithTransform` keeps
    /// EXIF-rotated phone photos upright. Returns nil on any decode failure.
    nonisolated static func imageIODownsample(data: Data, maxPixel: Int) -> CGImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }
        let options =
            [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: max(1, maxPixel),
            ] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
    }
}

#if canImport(UIKit)
/// The concrete image the loader caches — `UIImage` on iOS.
public typealias DODImage = UIImage

extension UIImage {
    /// Pixel-dimension shim so cross-platform code and tests can read
    /// `.width` / `.height` uniformly on a `DODImage`. On the non-UIKit
    /// `swift test` slice `DODImage` is a `CGImage`, which exposes these
    /// natively as `Int` pixel counts; `UIImage` only offers `.size`
    /// (points). These bridge to the backing `CGImage`'s pixel dimensions
    /// (what the downsampler actually caps), falling back to point-size ×
    /// scale when there is no backing bitmap — so `.width` / `.height`
    /// compile and mean the same thing on both platforms.
    var width: Int { cgImage?.width ?? Int((size.width * scale).rounded()) }
    var height: Int { cgImage?.height ?? Int((size.height * scale).rounded()) }
}
#else
/// On non-UIKit hosts (the `swift test` slice) the cache holds the raw
/// `CGImage`, so the downsampler + cache are still exercised cross-platform.
public typealias DODImage = CGImage
#endif

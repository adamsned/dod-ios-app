import CoreSpotlight
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Pure, host-free core of the Spotlight (re)index (US-10 / AC-10.3), extracted
/// from ``RootView/indexSpotlight()`` so the memory-bounding contract can be
/// unit-tested without a SwiftUI host.
///
/// DUT-467 — the old path materialized ALL suggested items (up to
/// ``RecipeEntityQuery/suggestedPayloads(limit:)``'s 60) in one `[CSSearchableItem]`
/// array before the single `indexSearchableItems` call, each item retaining up
/// to ~1 MB of full-res hero JPEG (worst case ~60 MB transient). This indexer
/// fixes that on two axes:
///
/// 1. **Downsample** every hero blob to a small thumbnail (``thumbnailMaxPixel``)
///    before it is attached to the attribute set, so a single retained blob is
///    kilobytes rather than a full-res JPEG — this also removes the need for the
///    old 1 MB skip-guard and matches what CoreSpotlight actually renders.
/// 2. **Batch** the index so at most ``batchSize`` items (and therefore at most
///    that many downsampled blobs) are held at once: each batch is built, handed
///    to the sink, and released before the next batch is built.
///
/// The CoreSpotlight-facing behavior is unchanged — the same searchable items
/// (same identifiers / attribute sets) are still produced and indexed; only the
/// peak in-memory footprint is bounded.
struct SpotlightIndexer {

    /// Max number of items — and therefore downsampled thumbnail blobs — held in
    /// memory at once. A batch is materialized, indexed, and released before the
    /// next is built, so peak footprint is `batchSize` thumbnails, not all 60.
    let batchSize: Int

    /// Longest-edge pixel bound for the re-encoded Spotlight thumbnail. 300 px
    /// matches the Spotlight result-row render size (DUT-467 suggested fix).
    let thumbnailMaxPixel: Int

    /// Non-touching cached hero bytes for a payload's hero URL, or nil when the
    /// image isn't on disk (CoreSpotlight never fetches remote thumbnails, so a
    /// miss simply leaves the thumbnail nil). Injected so tests supply blobs
    /// without a store.
    let cachedHeroBytes: @Sendable (RecipeEntityPayload) async -> Data?

    /// Downsample+re-encode raw hero bytes to a thumbnail no larger than
    /// `thumbnailMaxPixel` on its longest edge. Defaults to an ImageIO
    /// implementation; injectable so tests can assert the seam is exercised and
    /// measure the resulting (bounded) blob size deterministically.
    let downsample: @Sendable (Data, Int) -> Data?

    /// Index one batch of already-built searchable items. Called once per batch;
    /// the live wiring routes this to `CSSearchableIndex.indexSearchableItems`.
    let indexBatch: @Sendable ([CSSearchableItem]) async throws -> Void

    init(
        batchSize: Int = 12,
        thumbnailMaxPixel: Int = 300,
        cachedHeroBytes: @escaping @Sendable (RecipeEntityPayload) async -> Data?,
        downsample: @escaping @Sendable (Data, Int) -> Data? = SpotlightIndexer.imageIODownsample,
        indexBatch: @escaping @Sendable ([CSSearchableItem]) async throws -> Void
    ) {
        self.batchSize = batchSize
        self.thumbnailMaxPixel = thumbnailMaxPixel
        self.cachedHeroBytes = cachedHeroBytes
        self.downsample = downsample
        self.indexBatch = indexBatch
    }

    /// Build + index the searchable items for `payloads` in bounded batches.
    ///
    /// For each payload we build the attribute set, attach a DOWNSAMPLED hero
    /// thumbnail when the hero bytes are cached, and accumulate into the current
    /// batch. Once the batch reaches ``batchSize`` it is flushed to ``indexBatch``
    /// and cleared, so no more than `batchSize` thumbnail blobs are ever held at
    /// once. Any final partial batch is flushed at the end.
    func index(payloads: [RecipeEntityPayload]) async throws {
        var batch: [CSSearchableItem] = []
        batch.reserveCapacity(min(batchSize, payloads.count))
        for payload in payloads {
            let entity = RecipeEntity(payload: payload)
            let set = entity.attributeSet
            if let raw = await cachedHeroBytes(payload) {
                // DUT-467 — downsample before retaining; a single held blob is
                // now a small thumbnail, not a full-res JPEG.
                set.thumbnailData = downsample(raw, thumbnailMaxPixel)
            }
            batch.append(
                CSSearchableItem(
                    uniqueIdentifier: "dod.recipe.\(payload.id)",
                    domainIdentifier: SpotlightIndexer.recipeDomainIdentifier,
                    attributeSet: set
                )
            )
            if batch.count >= batchSize {
                try await indexBatch(batch)
                batch.removeAll(keepingCapacity: true)
            }
        }
        if !batch.isEmpty {
            try await indexBatch(batch)
        }
    }

    /// CoreSpotlight domain identifier for indexed recipes (matches the
    /// pre-DUT-467 literal used in the delete + index calls).
    static let recipeDomainIdentifier = "com.dutchovendaddy.DODApp.recipes"

    /// Default downsampler: decode `data` at a thumbnail scale via ImageIO
    /// (`CGImageSourceCreateThumbnailAtIndex`, which never fully decodes the
    /// full-res image into RAM) and re-encode as JPEG. Returns nil on any
    /// decode/encode failure — the caller then simply omits the thumbnail.
    ///
    /// Lives in the App target (not DODDesignSystem's `ImageDownsampler`, which
    /// is in a locked lane) and is intentionally standalone.
    static func imageIODownsample(_ data: Data, maxPixel: Int) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard
            let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else {
            return nil
        }
        let out = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(
                out as CFMutableData,
                UTType.jpeg.identifier as CFString,
                1,
                nil
            )
        else {
            return nil
        }
        CGImageDestinationAddImage(destination, thumbnail, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return out as Data
    }
}

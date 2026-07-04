import CoreSpotlight
import DODAnalytics
import DODPersistence
import DODSupport
import SwiftUI

extension RootView {

    /// Re-index Spotlight on each foreground return so later-session saves stay
    /// searchable without a cold launch; the launch `.active` is gated (DUT-12).
    func reindexSpotlightOnForeground(_ newPhase: ScenePhase) {
        guard newPhase == .active, didInitialSpotlightIndex else { return }
        Task { await indexSpotlight() }
    }

    /// (Re)index the suggested recipes into Spotlight (US-10 / DUT-12). Extracted
    /// here so `RootView` stays under the SwiftLint file_length / type_body_length
    /// caps.
    func indexSpotlight() async {
        // DUT-361: serialize — a foreground bounce can fire a second reindex while
        // the first is still awaiting; running them concurrently can interleave the
        // domain delete + index. One at a time keeps delete+index atomic per run.
        guard !isIndexingSpotlight else { return }
        isIndexingSpotlight = true
        defer { isIndexingSpotlight = false }
        do {
            let payloads = try await RecipeEntityQuery.suggestedPayloads()
            let store = AppIntentEnvironment.store
            let index = CSSearchableIndex.default()
            // DUT-308: drop the whole recipe domain before each (re)index so an
            // unsaved/cleared recipe doesn't linger in Spotlight (was upsert-only).
            try await index.deleteSearchableItems(withDomainIdentifiers: [
                SpotlightIndexer.recipeDomainIdentifier
            ])
            // DUT-467 — index in bounded batches with DOWNSAMPLED thumbnails so we
            // never materialize all ~60 full-res hero JPEGs at once. The indexer
            // handles the downsample + batching; here we only wire the seams.
            let indexer = SpotlightIndexer(
                cachedHeroBytes: { payload in
                    await Self.cachedThumbnailBytes(for: payload.heroImage, store: store)
                },
                indexBatch: { batch in try await index.indexSearchableItems(batch) }
            )
            try await indexer.index(payloads: payloads)
        } catch {
            DODLog.app.error("spotlight index failed: \(String(describing: error))")
        }
    }

    /// DUT-412 — the cached hero bytes for a Spotlight thumbnail, or nil when the
    /// image isn't cached or there's no store yet. CoreSpotlight never fetches
    /// remote thumbnails, so we only ever attach LOCAL bytes and never touch the
    /// network during indexing. DUT-467 — no size guard here: `SpotlightIndexer`
    /// downsamples every blob to a small thumbnail, so a large original is bounded
    /// rather than skipped.
    static func cachedThumbnailBytes(for heroImage: URL?, store: RecipeStore?) async -> Data? {
        guard let heroImage, let store else { return nil }
        return try? await store.imageBytesWithoutTouching(url: heroImage)
    }
}

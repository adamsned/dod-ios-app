import CoreSpotlight
import DODAnalytics
import DODPersistence
import DODSupport
import SwiftUI

extension RootView {

    /// DUT-643 — minimum wall-clock gap between foreground Spotlight re-indexes.
    /// A foreground return within this window skips the full delete+rebuild+
    /// downsample entirely; a longer gap still only reindexes if the suggested
    /// set actually changed (see ``reindexSpotlightOnForeground(_:)``).
    static let spotlightMinReindexInterval: TimeInterval = 5 * 60

    /// Re-index Spotlight on each foreground return so later-session saves stay
    /// searchable without a cold launch; the launch `.active` is gated (DUT-12).
    ///
    /// DUT-643 — the reindex is no longer unconditional: the full
    /// delete+rebuild+downsample only runs when BOTH (a) at least
    /// ``spotlightMinReindexInterval`` has elapsed since the last successful
    /// index, and (b) the suggested-recipe set has actually changed since then.
    /// An unchanged set (or a rapid re-foreground) is a no-op, so a foreground
    /// bounce doesn't repeatedly re-downsample ~60 hero JPEGs.
    func reindexSpotlightOnForeground(_ newPhase: ScenePhase) {
        guard newPhase == .active, didInitialSpotlightIndex else { return }
        let sinceLast = lastSpotlightIndexAt.map { Date().timeIntervalSince($0) }
        let withinThrottle = (sinceLast ?? .greatestFiniteMagnitude) < Self.spotlightMinReindexInterval
        if withinThrottle { return }
        Task { await indexSpotlight(onlyIfChanged: true) }
    }

    /// (Re)index the suggested recipes into Spotlight (US-10 / DUT-12). Extracted
    /// here so `RootView` stays under the SwiftLint file_length / type_body_length
    /// caps.
    ///
    /// - Parameter onlyIfChanged: when `true` (the foreground path) the index is
    ///   skipped if the suggested-recipe id set matches the last successful
    ///   index (DUT-643 dirty gate). The cold-launch call leaves it `false` so
    ///   the very first index always runs.
    func indexSpotlight(onlyIfChanged: Bool = false) async {
        // DUT-361: serialize — a foreground bounce can fire a second reindex while
        // the first is still awaiting; running them concurrently can interleave the
        // domain delete + index. One at a time keeps delete+index atomic per run.
        guard !isIndexingSpotlight else { return }
        isIndexingSpotlight = true
        defer { isIndexingSpotlight = false }
        do {
            let payloads = try await RecipeEntityQuery.suggestedPayloads()
            let newIdentifiers = Set(payloads.map { "dod.recipe.\($0.id)" })
            // DUT-643 — skip the whole rebuild when the suggested set is unchanged.
            if onlyIfChanged, newIdentifiers == lastIndexedSpotlightIdentifiers {
                return
            }
            let store = AppIntentEnvironment.store
            let index = CSSearchableIndex.default()
            // DUT-467 — index in bounded batches with DOWNSAMPLED thumbnails so we
            // never materialize all ~60 full-res hero JPEGs at once. The indexer
            // handles the downsample + batching; here we only wire the seams.
            let indexer = SpotlightIndexer(
                cachedHeroBytes: { payload in
                    await Self.cachedThumbnailBytes(for: payload.heroImage, store: store)
                },
                indexBatch: { batch in try await index.indexSearchableItems(batch) }
            )
            // DUT-642 — index the NEW batch FIRST (upsert), then delete only the
            // stale identifiers no longer present. The old code deleted the whole
            // recipe domain up front, so a batch failure left Spotlight empty with
            // nothing to replace it. Index-then-diff-delete guarantees a failure
            // can never wipe the index without a replacement in place.
            try await indexer.index(payloads: payloads)
            let staleIdentifiers = lastIndexedSpotlightIdentifiers.subtracting(newIdentifiers)
            if !staleIdentifiers.isEmpty {
                try await index.deleteSearchableItems(withIdentifiers: Array(staleIdentifiers))
            }
            // Record success so the next diff-delete + dirty gate have a baseline.
            lastIndexedSpotlightIdentifiers = newIdentifiers
            lastSpotlightIndexAt = Date()
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

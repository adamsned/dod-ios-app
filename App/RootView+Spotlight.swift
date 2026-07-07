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
        // DUT-687 — the throttle decision moved INTO `indexSpotlight`: the old
        // early-return here skipped the reindex on the wall-clock floor BEFORE the
        // dirty check, so a fresh save within 5 min wasn't reflected until the next
        // launch. Now a genuine suggested-set CHANGE bypasses the time floor; only
        // the no-change bounce (the case the throttle exists to avoid re-downsampling
        // ~60 hero JPEGs for) is throttled. The concurrent-run guard still lives in
        // `indexSpotlight`, so a rapid double-foreground can't race.
        Task { await indexSpotlight(onlyIfChanged: true, throttleUnchanged: true) }
    }

    /// (Re)index the suggested recipes into Spotlight (US-10 / DUT-12). Extracted
    /// here so `RootView` stays under the SwiftLint file_length / type_body_length
    /// caps.
    ///
    /// - Parameters:
    ///   - onlyIfChanged: when `true` (the foreground path) the index is skipped
    ///     if the suggested-recipe id set matches the last successful index
    ///     (DUT-643 dirty gate). The cold-launch call leaves it `false` so the
    ///     very first index always runs.
    ///   - throttleUnchanged: DUT-687 — when `true` (the foreground path) the
    ///     ``RootView/spotlightMinReindexInterval`` wall-clock floor applies ONLY
    ///     to an unchanged set (the no-change bounce the throttle exists to avoid).
    ///     A genuine set change bypasses the floor so a fresh save within the
    ///     window is reflected immediately rather than waiting for the next launch.
    func indexSpotlight(onlyIfChanged: Bool = false, throttleUnchanged: Bool = false) async {
        // DUT-361: serialize — a foreground bounce can fire a second reindex while
        // the first is still awaiting; running them concurrently can interleave the
        // domain delete + index. One at a time keeps delete+index atomic per run.
        guard !isIndexingSpotlight else { return }
        isIndexingSpotlight = true
        defer { isIndexingSpotlight = false }
        do {
            let payloads = try await RecipeEntityQuery.suggestedPayloads()
            let newIdentifiers = Set(payloads.map { "dod.recipe.\($0.id)" })
            let setUnchanged = newIdentifiers == lastIndexedSpotlightIdentifiers
            // DUT-687 — evaluate the set change BEFORE the wall-clock floor so a
            // genuine change always reindexes; the throttle only suppresses the
            // no-change bounce (the case it exists for: avoid re-downsampling ~60
            // hero JPEGs on a rapid re-foreground). The old code returned on the
            // floor in `reindexSpotlightOnForeground` before this dirty check, so a
            // fresh save within the 5-min window wasn't reflected until relaunch.
            //
            // DUT-643 — the dirty gate: an unchanged set is a no-op on the
            // foreground path (`onlyIfChanged`). `throttleUnchanged` is the same
            // foreground path's belt-and-suspenders time floor, kept so an unchanged
            // bounce can never fall through to a rebuild. A CHANGED set falls through
            // both gates and reindexes regardless of elapsed time.
            let sinceLast = lastSpotlightIndexAt.map { Date().timeIntervalSince($0) }
            let withinThrottle =
                (sinceLast ?? .greatestFiniteMagnitude) < Self.spotlightMinReindexInterval
            let dirtyGateSkip = onlyIfChanged && setUnchanged
            let throttleSkip = throttleUnchanged && setUnchanged && withinThrottle
            if dirtyGateSkip || throttleSkip {
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
            // DUT-684 — `lastIndexedSpotlightIdentifiers` is `@State`, reset empty
            // on every cold launch, so on the FIRST index of a process the diff-
            // delete has no baseline and can't remove entries a prior session left
            // behind (a recipe unsaved last session → dead tap that opens nothing,
            // DUT-308). Purge the WHOLE recipe domain once per launch to clear those
            // cross-launch stragglers, THEN rebuild. A full-domain purge can't
            // exclude the current ids, so it must precede the index (can't upsert-
            // first here without deleting what we just wrote); the window where the
            // domain is empty is only until the rebuild below completes.
            let isFirstIndexThisLaunch = !hasPurgedSpotlightDomainThisLaunch
            if isFirstIndexThisLaunch {
                try await index.deleteSearchableItems(
                    withDomainIdentifiers: [SpotlightIndexer.recipeDomainIdentifier]
                )
                hasPurgedSpotlightDomainThisLaunch = true
            }
            // DUT-642 — index the NEW batch FIRST (upsert), then (on subsequent
            // same-process reindexes) delete only the stale identifiers no longer
            // present. The old code deleted the whole recipe domain up front, so a
            // batch failure left Spotlight empty with nothing to replace it. Index-
            // then-diff-delete guarantees a failure can never wipe the index without
            // a replacement in place.
            try await indexer.index(payloads: payloads)
            if !isFirstIndexThisLaunch {
                let staleIdentifiers = lastIndexedSpotlightIdentifiers.subtracting(newIdentifiers)
                if !staleIdentifiers.isEmpty {
                    try await index.deleteSearchableItems(withIdentifiers: Array(staleIdentifiers))
                }
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

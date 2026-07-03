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
            var items: [CSSearchableItem] = []
            items.reserveCapacity(payloads.count)
            for payload in payloads {
                let entity = RecipeEntity(payload: payload)
                let set = entity.attributeSet
                // DUT-412 — CoreSpotlight only renders LOCAL thumbnails. Attach the
                // cached hero bytes when we already have them on disk (non-touching
                // read, no LRU promotion); skip oversized blobs and never fetch over
                // the network during indexing. Leaves the thumbnail nil otherwise.
                set.thumbnailData = await cachedThumbnailBytes(for: payload.heroImage, store: store)
                items.append(
                    CSSearchableItem(
                        uniqueIdentifier: "dod.recipe.\(payload.id)",
                        domainIdentifier: "com.dutchovendaddy.DODApp.recipes",
                        attributeSet: set
                    )
                )
            }
            // DUT-308: drop the whole recipe domain before each (re)index so an
            // unsaved/cleared recipe doesn't linger in Spotlight (was upsert-only).
            let index = CSSearchableIndex.default()
            try await index.deleteSearchableItems(withDomainIdentifiers: [
                "com.dutchovendaddy.DODApp.recipes"
            ])
            try await index.indexSearchableItems(items)
        } catch {
            DODLog.app.error("spotlight index failed: \(String(describing: error))")
        }
    }

    /// DUT-412 — the cached hero bytes for a Spotlight thumbnail, or nil when the
    /// image isn't cached, is too large (> 1MB), or there's no store yet.
    /// CoreSpotlight never fetches remote thumbnails, so we only ever attach LOCAL
    /// bytes and never touch the network during indexing.
    private func cachedThumbnailBytes(for heroImage: URL?, store: RecipeStore?) async -> Data? {
        guard let heroImage, let store else { return nil }
        guard let bytes = try? await store.imageBytesWithoutTouching(url: heroImage) else {
            return nil
        }
        return bytes.count <= 1_000_000 ? bytes : nil
    }
}

import DODSupport
import Foundation
import SwiftData

/// Image bytes cache + eviction policy, extracted from the main `RecipeStore`
/// actor body to keep that file under SwiftLint's `type_body_length` cap
/// once the US-21 widget image bridge wiring landed.
///
/// The bridge (``WidgetImageBridge``) is the single side-effect path between
/// the SwiftData store and the shared App Group container. Writes mirror to
/// the container at deterministic filenames; eviction deletes the matching
/// file alongside the SwiftData row. Failures are best-effort and logged
/// inside the bridge — the widget gracefully falls back to its gradient
/// placeholder when a file is absent.
///
/// Spec trace: T-075 (image cache + 200 MB budget, NFR-2), T-360 / US-21
/// AC-21.2 (write hook), AC-21.4 (eviction parity), CL-35 (bridge choice).
extension RecipeStore {

    public func cacheImage(url: URL, bytes: Data, pinnedToSavedRecipeID: Int? = nil) throws {
        let urlString = url.absoluteString
        // Diagnostic surface for REG-T-360 / CL-45. A future regression
        // where the snapshot writer plumbs filenames but no caller
        // actually pushes bytes through here would otherwise be invisible
        // — the widget would silently render the gradient placeholder
        // and the only evidence in the file system is an empty
        // `widget-images/` directory. Logging at debug level keeps the
        // signal out of normal `Console.app` chatter but makes it
        // observable when filtering for `subsystem == "app.dod"`.
        DODLog.persistence.debug(
            "cacheImage byte-write: \(bytes.count, privacy: .public)B for \(urlString, privacy: .public)"
        )
        let descriptor = FetchDescriptor<CachedImage>(
            predicate: #Predicate { $0.urlString == urlString }
        )
        if let existing = try modelContext.fetch(descriptor).first {
            existing.bytes = bytes
            existing.byteCount = bytes.count  // DUT-242: keep the scalar in sync.
            existing.lastUsedAt = .now
            if let pin = pinnedToSavedRecipeID {
                existing.pinnedToSavedRecipeID = pin
            }
        } else {
            modelContext.insert(
                CachedImage(
                    urlString: urlString,
                    bytes: bytes,
                    pinnedToSavedRecipeID: pinnedToSavedRecipeID
                )
            )
        }
        try modelContext.save()
        // Widget image bridge (spec.md AC-21.2). Best-effort file write
        // into the shared App Group container so the widget extension can
        // render the bytes without a network fetch. Failures are logged
        // and swallowed inside the bridge — the widget gracefully falls
        // back to its gradient placeholder when the file is absent.
        WidgetImageBridge.writeImage(bytes: bytes, for: url)
        try evictImagesIfNeeded()
    }

    public func image(url: URL) throws -> Data? {
        let urlString = url.absoluteString
        let descriptor = FetchDescriptor<CachedImage>(
            predicate: #Predicate { $0.urlString == urlString }
        )
        guard let row = try modelContext.fetch(descriptor).first else { return nil }
        row.lastUsedAt = .now
        try modelContext.save()
        return row.bytes
    }

    /// Purge every unpinned `CachedImage` row + its App Group file
    /// bridge mirror. Returns the total bytes freed so the Settings
    /// row's snackbar can format a humane "Freed X.X MB" message
    /// (US-36 / AC-36.4).
    ///
    /// Pinned rows (saved-recipe images, `pinnedToSavedRecipeID != nil`)
    /// are preserved — those bytes belong to the AC-5.2 offline
    /// pre-download contract, and wiping them would make saved recipes
    /// lose their hero images until the next online visit (regression
    /// against AC-4.9 "fully usable offline if saved"). The exempt-pinned
    /// semantics mirror `evictImagesIfNeeded()`'s NFR-2 contract — same
    /// rule, applied unconditionally rather than budget-gated.
    ///
    /// File deletion via ``WidgetImageBridge/deleteImage(for:)`` is
    /// best-effort, mirroring the evict path. SwiftData remains
    /// authoritative; a stale file in the App Group container would
    /// only manifest as an orphan widget render until the next
    /// `cacheImage(...)` call overwrites it.
    ///
    /// Spec trace: US-36 AC-36.4.
    @discardableResult
    public func clearImageCache() throws -> Int {
        try backfillImageByteCountsIfNeeded()
        var descriptor = FetchDescriptor<CachedImage>(
            predicate: #Predicate { $0.pinnedToSavedRecipeID == nil }
        )
        // DUT-242: sum the scalar, don't fault every blob just to count its bytes.
        descriptor.propertiesToFetch = [\.byteCount, \.urlString, \.pinnedToSavedRecipeID]
        let unpinned = try modelContext.fetch(descriptor)
        var freedBytes = 0
        for row in unpinned {
            freedBytes += row.byteCount
            if let url = URL(string: row.urlString) { WidgetImageBridge.deleteImage(for: url) }
            modelContext.delete(row)
        }
        try modelContext.save()
        return freedBytes
    }

    /// Trim image rows until total bytes ≤ ``imageBudgetBytes``. Pinned rows
    /// (saved-recipe images) are excluded from eviction (NFR-2). When a
    /// row is evicted the corresponding App Group file (the widget image
    /// bridge mirror, spec.md AC-21.4) is also deleted so the two stores
    /// never drift. File deletion is best-effort — failures are logged
    /// and swallowed inside the bridge.
    public func evictImagesIfNeeded() throws {
        try backfillImageByteCountsIfNeeded()
        var descriptor = FetchDescriptor<CachedImage>(
            sortBy: [SortDescriptor(\.lastUsedAt, order: .forward)]
        )
        // DUT-242: prefetch only the scalar metadata, NOT `bytes`, so summing the
        // 200 MB budget no longer faults every cached image's full payload into
        // RAM on every `cacheImage` (every feed/search/saved scroll).
        descriptor.propertiesToFetch = [
            \.byteCount, \.lastUsedAt, \.urlString, \.pinnedToSavedRecipeID,
        ]
        let all = try modelContext.fetch(descriptor)
        var total = all.reduce(0) { $0 + $1.byteCount }
        guard total > Self.imageBudgetBytes else { return }
        for row in all where row.pinnedToSavedRecipeID == nil {
            let size = row.byteCount
            if let url = URL(string: row.urlString) { WidgetImageBridge.deleteImage(for: url) }
            modelContext.delete(row)
            total -= size
            if total <= Self.imageBudgetBytes { break }
        }
        try modelContext.save()
    }

    /// DUT-215: clear the save-pin on every cached image belonging to
    /// `recipeID`. `pinnedToSavedRecipeID` was write-once (set when a saved
    /// recipe's hero is cached, never cleared), so unsaving a recipe left its
    /// pinned bytes un-evictable — neither ``evictImagesIfNeeded()`` nor the
    /// Settings ``clearImageCache()`` could reclaim a pinned row. Unsaving now
    /// unpins so the bytes become reclaimable again. The caller persists.
    func unpinImages(forRecipeID recipeID: Int) throws {
        let all = try modelContext.fetch(FetchDescriptor<CachedImage>())
        for row in all where row.pinnedToSavedRecipeID == recipeID {
            row.pinnedToSavedRecipeID = nil
        }
    }

    /// DUT-242: one-time (per launch) backfill of `byteCount` for rows written
    /// before the column existed (default 0). Faults each such row's bytes ONCE
    /// to set the scalar; once `didBackfillImageByteCounts` flips, later calls
    /// are a cheap fetch with nothing to do — so the eviction + clear-cache
    /// budget sums stay accurate without re-reading blobs.
    func backfillImageByteCountsIfNeeded() throws {
        guard !didBackfillImageByteCounts else { return }
        let all = try modelContext.fetch(FetchDescriptor<CachedImage>())
        var changed = false
        for row in all where row.byteCount == 0 && !row.bytes.isEmpty {
            row.byteCount = row.bytes.count
            changed = true
        }
        if changed { try modelContext.save() }
        didBackfillImageByteCounts = true
    }
}

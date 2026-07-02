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
        // DUT-292: if the caller didn't pin explicitly, auto-pin when this URL is
        // the hero of a currently-saved recipe — so the post-save widget prefetch
        // (which caches the hero with no pin) still produces an eviction-proof
        // row, keeping a merely-saved recipe offline-usable (AC-5.2).
        // DUT-380 + DUT-292: resolve the pin to REALITY. An explicit pin (the
        // offline-download path) can race an unsave — `downloadForOffline` awaits
        // the network OUTSIDE this actor, so the recipe may have been unsaved by
        // the time the bytes land. Honor the explicit pin only while the recipe is
        // still saved/downloaded; else fall back to the saved-hero auto-pin, so we
        // never pin to a recipe nothing references (which would escape both
        // eviction and Clear Cache forever — re-opening the DUT-215 leak).
        let effectivePin = try resolveImagePin(explicit: pinnedToSavedRecipeID, heroURLString: urlString)
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
            if let pin = effectivePin {
                existing.pinnedToSavedRecipeID = pin
            }
        } else {
            modelContext.insert(
                CachedImage(
                    urlString: urlString,
                    bytes: bytes,
                    pinnedToSavedRecipeID: effectivePin
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

    /// DUT-380: honor an explicit download pin only while its recipe is still
    /// live (saved or downloaded); otherwise fall back to the saved-hero auto-pin
    /// (DUT-292), so a download that raced an unsave can't pin bytes to a recipe
    /// nothing references.
    private func resolveImagePin(explicit: Int?, heroURLString: String) throws -> Int? {
        if let explicit, try isPinTargetStillLive(explicit) { return explicit }
        return try savedRecipeID(forHeroURLString: heroURLString)
    }

    private func isPinTargetStillLive(_ recipeID: Int) throws -> Bool {
        if try fetchSyncedSaved(id: recipeID) != nil { return true }
        return try fetchRecipe(id: recipeID)?.downloadedAt != nil
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

    /// DUT-412 — non-touching byte read for Spotlight thumbnail indexing.
    /// Returns the cached bytes for `url` WITHOUT bumping `lastUsedAt` (parity
    /// with ``recipeWithoutTouching`` / ``hasBridgedImage``): indexing must not
    /// promote rows in the image LRU over images the user actually viewed.
    /// Returns nil when the image isn't cached — CoreSpotlight never fetches a
    /// remote thumbnail, so the caller simply omits the thumbnail in that case.
    public func imageBytesWithoutTouching(url: URL) throws -> Data? {
        let urlString = url.absoluteString
        var descriptor = FetchDescriptor<CachedImage>(
            predicate: #Predicate { $0.urlString == urlString }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.bytes
    }

    /// DUT-442 — existence probe for background jobs (the feed widget-snapshot
    /// prefetch gate). Unlike ``image(url:)`` it does NOT bump `lastUsedAt`
    /// (a snapshot job must not promote rows in the image LRU over images the
    /// user actually viewed — parity with `recipeWithoutTouching`), does NOT
    /// fault the blob, and also requires the App Group bridge FILE to exist —
    /// `writeImage` is best-effort, so a row can exist with no file, and
    /// gating on the row alone would skip the re-fetch that self-heals the
    /// widget's gradient placeholder (DUT-227 family).
    public func hasBridgedImage(url: URL) throws -> Bool {
        let urlString = url.absoluteString
        var descriptor = FetchDescriptor<CachedImage>(
            predicate: #Predicate { $0.urlString == urlString }
        )
        descriptor.propertiesToFetch = [\.urlString]
        descriptor.fetchLimit = 1
        guard try !modelContext.fetch(descriptor).isEmpty else { return false }
        let filename = WidgetImageBridge.filename(for: url)
        guard let fileURL = WidgetImageBridge.fileURL(forFilename: filename) else { return false }
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    /// DUT-227 — fired (best-effort) after ``evictImagesIfNeeded()`` deletes
    /// bridged image files, so the app layer can `WidgetCenter.reloadTimelines`
    /// and a published snapshot doesn't keep naming a now-missing file (stuck
    /// gradient placeholder until the 4-hour refresh). Static because the
    /// persistence package can't import WidgetKit; `AppDependencies.bootstrap`
    /// wires it once at launch.
    nonisolated(unsafe) public static var onBridgedImagesEvicted: (@Sendable () -> Void)?

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
        var evictedAny = false
        for row in all where row.pinnedToSavedRecipeID == nil {
            let size = row.byteCount
            if let url = URL(string: row.urlString) { WidgetImageBridge.deleteImage(for: url) }
            modelContext.delete(row)
            evictedAny = true
            total -= size
            if total <= Self.imageBudgetBytes { break }
        }
        try modelContext.save()
        // DUT-227: an evicted bridge file may be the one a PUBLISHED widget
        // snapshot references — tell the app layer to reload timelines so the
        // widget re-renders (and re-fetches) instead of showing the gradient
        // placeholder until its 4-hour refresh.
        if evictedAny { Self.onBridgedImagesEvicted?() }
    }

    /// DUT-292: the id of a currently-saved recipe whose hero image is
    /// `urlString`, if any — lets `cacheImage` auto-pin a hero cached AFTER the
    /// save (the post-save widget prefetch caches with no pin), so a merely-saved
    /// recipe's hero is eviction-proof for offline use (AC-5.2).
    private func savedRecipeID(forHeroURLString urlString: String) throws -> Int? {
        var descriptor = FetchDescriptor<CachedRecipe>(
            predicate: #Predicate { $0.isSaved && $0.heroImageURLString == urlString }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.id
    }

    /// DUT-292: pin a just-saved recipe's hero image row if it's already cached
    /// (the common case — the hero was on screen when the user tapped Save). The
    /// cache-after-save case is covered by `cacheImage`'s auto-pin. Caller saves.
    func pinHeroImage(heroURLString: String?, toRecipeID recipeID: Int) throws {
        guard let heroURLString else { return }
        var descriptor = FetchDescriptor<CachedImage>(
            predicate: #Predicate { $0.urlString == heroURLString }
        )
        descriptor.fetchLimit = 1
        if let imageRow = try modelContext.fetch(descriptor).first {
            imageRow.pinnedToSavedRecipeID = recipeID
        }
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

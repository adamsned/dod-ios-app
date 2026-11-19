import Foundation

/// DUT-2255 — small Siri / Shortcuts thumbnails for ``RecipeEntity``, made only
/// from hero bytes already in the on-device image cache (never a download).
///
/// Shortcuts asks for suggestions often, so each thumbnail is downsampled once
/// and memoized for the process. A miss (hero not cached yet) is not memoized,
/// so the photo shows up once the recipe has been opened.
actor RecipeEntityThumbnails {

    static let shared = RecipeEntityThumbnails()

    /// Longest edge, in pixels. Siri / Shortcuts render entity images small.
    static let maxPixel = 120

    private var cache: [URL: Data] = [:]

    func thumbnail(for heroImage: URL?) async -> Data? {
        guard let heroImage else { return nil }
        if let hit = cache[heroImage] { return hit }
        // Straight to the store actor (not via a MainActor view helper), so a
        // background Shortcuts query never waits on the main thread.
        guard
            let store = AppIntentEnvironment.store,
            let raw = try? await store.imageBytesWithoutTouching(url: heroImage),
            let small = SpotlightIndexer.imageIODownsample(raw, maxPixel: Self.maxPixel)
        else { return nil }
        cache[heroImage] = small
        return small
    }
}

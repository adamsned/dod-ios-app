import DODDomain
import Foundation
import Testing

@testable import DODPersistence

/// DUT-242: `CachedImage.byteCount` is a denormalized copy of `bytes.count` that
/// eviction + clear-cache sum (via `propertiesToFetch`) instead of faulting
/// every image's full payload into RAM. These pin that the scalar is kept in
/// sync on writes (the existing `clearImageCache*` tests already prove it is
/// populated + summed — a broken `byteCount` would free 0 there).
@Suite("RecipeStore image byteCount (DUT-242)") struct RecipeStoreImageByteCountTests {

    @Test func reCachingAnImageUpdatesItsByteCount() async throws {
        let store = try await makeStore()
        let url = URL(string: "https://example.com/x.jpg") ?? URL(filePath: "/")
        try await store.cacheImage(url: url, bytes: Data(repeating: 0x01, count: 100))
        // Overwrite the same URL with a larger payload — the update path must
        // refresh byteCount, else eviction/clear would account the stale size.
        try await store.cacheImage(url: url, bytes: Data(repeating: 0x02, count: 2_000))

        let freed = try await store.clearImageCache()
        #expect(freed == 2_000, "clear frees the CURRENT byteCount, not the original 100")
    }
}

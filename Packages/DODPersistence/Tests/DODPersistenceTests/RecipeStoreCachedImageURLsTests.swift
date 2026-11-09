import Foundation
import Testing

@testable import DODPersistence

@Suite struct RecipeStoreCachedImageURLsTests {
    @Test func returnsOnlyCachedURLs() async throws {
        let store = RecipeStore(modelContainer: try RecipeStore.inMemoryContainer())
        let cachedURL = URL(fileURLWithPath: "/tmp/a.jpg")
        let missingURL = URL(fileURLWithPath: "/tmp/b.jpg")
        try await store.cacheImage(url: cachedURL, bytes: Data([1]))
        let found = try await store.cachedImageURLs(among: [cachedURL, missingURL])
        #expect(found == [cachedURL])
    }
}

import DODDomain
import Foundation
import Testing
@testable import DODPersistence

// MARK: - RecipeStore article classification (US-37 / T-640)
//
// Extracted from RecipeStoreTests.swift to keep that file under the
// SwiftLint 400-line file_length cap. Test helpers (`makeStore()`,
// `makeListItem(...)`) remain in the original file and are
// package-internal to this test target.

@Suite("RecipeStore article-classification (T-076 then T-640, AC-1.7 + AC-37.4)") struct BlocklistTests {

    // US-37 / CL-63 / AC-37.4 (T-640): the suite was originally
    // "RecipeStore blocklist" — articles were hidden from lists per CL-9.
    // Post-T-640 the `jsonLDFailedAt` field is the kind discriminator
    // (article vs recipe) and articles surface in lists alongside
    // recipes. The three tests below now lock the new behavior; the
    // `clearBlocklist()` pull-to-refresh-reset semantic is preserved
    // because it still flips an article back to recipe-rendering after
    // a server-side JSON-LD fix is published.

    @Test func articleClassifiedRowIsIncludedInListItems() async throws {
        // Pre-T-640: blocklisted row excluded. Post-T-640: article-
        // classified row included alongside recipe rows.
        let store = try await makeStore()
        try await store.cache(listItem: makeListItem(id: 1, title: "Healthy"))
        try await store.cache(listItem: makeListItem(id: 2, title: "Article"))
        try await store.markJSONLDFailed(id: 2)
        let visible = try await store.listItems(forIDs: [1, 2])
        #expect(Set(visible.map(\.id)) == Set([1, 2]))
    }

    @Test func clearBlocklistResetsArticleClassification() async throws {
        // The pull-to-refresh reset path is preserved (AC-37.4 last
        // sentence). After `clearBlocklist()` an article-classified row
        // surfaces with its `jsonLDFailedAt` cleared, so the next detail
        // open re-attempts the JSON-LD parse and (on server-side fix)
        // flips back to recipe rendering. The row is still visible
        // before+after the clear — what changes is the kind classification.
        let store = try await makeStore()
        try await store.cache(listItem: makeListItem(id: 5, title: "Foo"))
        try await store.markJSONLDFailed(id: 5)
        let beforeClear = try await store.listItems(forIDs: [5])
        #expect(beforeClear.count == 1)
        try await store.clearBlocklist()
        let afterClear = try await store.listItems(forIDs: [5])
        #expect(afterClear.count == 1)
    }

    @Test func successfulReCacheClearsArticleClassification() async throws {
        let store = try await makeStore()
        try await store.cache(listItem: makeListItem(id: 9, title: "Comeback"))
        try await store.markJSONLDFailed(id: 9)
        // Re-caching the same item (e.g. after pull-to-refresh) clears the flag.
        try await store.cache(listItem: makeListItem(id: 9, title: "Comeback"))
        let visible = try await store.listItems(forIDs: [9])
        #expect(visible.count == 1)
    }
}

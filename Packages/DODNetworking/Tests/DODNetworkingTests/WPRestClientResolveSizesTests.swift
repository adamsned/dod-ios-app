import Foundation
import Testing

@testable import DODNetworking

@Suite("WPRestClient.resolveSizes(from:)") struct WPRestClientResolveSizesTests {

    // MARK: - Test 1: List fallback chain — medium_large missing, medium present

    @Test func listFallsBackToMediumWhenMediumLargeAbsent() throws {
        let json = """
            {
              "source_url": "https://example.com/source.jpg",
              "media_details": {
                "sizes": {
                  "medium": { "source_url": "https://example.com/medium.jpg", "width": 300, "height": 200 }
                }
              }
            }
            """
        let media = try JSONDecoder().decode(WPDTO.Media.self, from: Data(json.utf8))
        let result = WPRestClient.resolveSizes(from: media)

        #expect(result.listImageURL?.absoluteString == "https://example.com/medium.jpg")
    }

    // MARK: - Test 2: List fallback chain — both medium_large and medium missing

    @Test func listFallsBackToSourceWhenNeitherPreferredSizePresent() throws {
        let json = """
            {
              "source_url": "https://example.com/source.jpg",
              "media_details": {
                "sizes": {
                  "large": { "source_url": "https://example.com/large.jpg", "width": 1024, "height": 682 },
                  "thumbnail": { "source_url": "https://example.com/thumb.jpg", "width": 150, "height": 150 }
                }
              }
            }
            """
        let media = try JSONDecoder().decode(WPDTO.Media.self, from: Data(json.utf8))
        let result = WPRestClient.resolveSizes(from: media)

        // List only checks medium_large and medium; neither is present, so falls back to sourceURL
        #expect(result.listImageURL?.absoluteString == "https://example.com/source.jpg")
    }

    // MARK: - Test 3: Hero — all sizes exceed 2048px width

    @Test func heroFallsBackToSourceWhenAllSizesExceed2048px() throws {
        let json = """
            {
              "source_url": "https://example.com/source.jpg",
              "media_details": {
                "sizes": {
                  "large": { "source_url": "https://example.com/large.jpg", "width": 3000, "height": 2000 },
                  "huge": { "source_url": "https://example.com/huge.jpg", "width": 4096, "height": 2730 }
                }
              }
            }
            """
        let media = try JSONDecoder().decode(WPDTO.Media.self, from: Data(json.utf8))
        let result = WPRestClient.resolveSizes(from: media)

        // All candidates filtered out (all > 2048), so falls back to sourceURL
        #expect(result.heroImageURL?.absoluteString == "https://example.com/source.jpg")
    }

    // MARK: - Test 4: Hero picks largest ≤2048px, independent from list

    @Test func heroPicsLargestCandidateIndependentFromList() throws {
        let json = """
            {
              "source_url": "https://example.com/source.jpg",
              "media_details": {
                "sizes": {
                  "medium": { "source_url": "https://example.com/medium.jpg", "width": 300, "height": 200 },
                  "large": { "source_url": "https://example.com/large.jpg", "width": 1024, "height": 682 },
                  "huge": { "source_url": "https://example.com/huge.jpg", "width": 4096, "height": 2730 }
                }
              }
            }
            """
        let media = try JSONDecoder().decode(WPDTO.Media.self, from: Data(json.utf8))
        let result = WPRestClient.resolveSizes(from: media)

        // List has no medium_large, so falls back to medium
        #expect(result.listImageURL?.absoluteString == "https://example.com/medium.jpg")
        // Hero: huge is filtered (4096 > 2048), candidates are [medium (300), large (1024)]
        // large wins as the largest ≤2048
        #expect(result.heroImageURL?.absoluteString == "https://example.com/large.jpg")
    }

    // MARK: - Test 5: Size with null/absent width

    @Test func heroHandlesSizeWithoutWidth() throws {
        let json = """
            {
              "source_url": "https://example.com/source.jpg",
              "media_details": {
                "sizes": {
                  "no_width": { "source_url": "https://example.com/no_width.jpg", "height": 200 },
                  "medium": { "source_url": "https://example.com/medium.jpg", "width": 300, "height": 200 }
                }
              }
            }
            """
        let media = try JSONDecoder().decode(WPDTO.Media.self, from: Data(json.utf8))
        let result = WPRestClient.resolveSizes(from: media)

        // List still falls back to source (no medium_large, no medium in this test's strict sense)
        // Actually, we DO have "medium", so list uses it
        #expect(result.listImageURL?.absoluteString == "https://example.com/medium.jpg")
        // Hero: no_width is treated as width 0 (<= 2048 passes filter)
        // candidates are [no_width (0), medium (300)], medium wins as largest
        #expect(result.heroImageURL?.absoluteString == "https://example.com/medium.jpg")
    }

    // MARK: - Test 6: Empty sizes dictionary but non-nil media_details

    @Test func bothFallBackToSourceWithEmptySizesDictionary() throws {
        let json = """
            {
              "source_url": "https://example.com/source.jpg",
              "media_details": {
                "sizes": {}
              }
            }
            """
        let media = try JSONDecoder().decode(WPDTO.Media.self, from: Data(json.utf8))
        let result = WPRestClient.resolveSizes(from: media)

        #expect(result.listImageURL?.absoluteString == "https://example.com/source.jpg")
        #expect(result.heroImageURL?.absoluteString == "https://example.com/source.jpg")
    }

    // MARK: - Test 7: media_details entirely absent (only sourceURL present)

    @Test func bothFallBackToSourceWithoutMediaDetails() throws {
        let json = """
            { "source_url": "https://example.com/only.jpg" }
            """
        let media = try JSONDecoder().decode(WPDTO.Media.self, from: Data(json.utf8))
        let result = WPRestClient.resolveSizes(from: media)

        #expect(result.listImageURL?.absoluteString == "https://example.com/only.jpg")
        #expect(result.heroImageURL?.absoluteString == "https://example.com/only.jpg")
    }

    // MARK: - Test 8: sourceURL is nil and sizes empty

    @Test func bothURLsNilWhenNoSourceAndNoSizes() throws {
        let json = """
            { "media_details": { "sizes": {} } }
            """
        let media = try JSONDecoder().decode(WPDTO.Media.self, from: Data(json.utf8))
        let result = WPRestClient.resolveSizes(from: media)

        #expect(result.listImageURL == nil)
        #expect(result.heroImageURL == nil)
    }

    // MARK: - Test 9: medium_large present and preferred for list

    @Test func listPrefersMediumLargeOverMedium() throws {
        let json = """
            {
              "source_url": "https://example.com/source.jpg",
              "media_details": {
                "sizes": {
                  "medium": { "source_url": "https://example.com/medium.jpg", "width": 300, "height": 200 },
                  "medium_large": { "source_url": "https://example.com/medium_large.jpg", "width": 768, "height": 512 }
                }
              }
            }
            """
        let media = try JSONDecoder().decode(WPDTO.Media.self, from: Data(json.utf8))
        let result = WPRestClient.resolveSizes(from: media)

        // List prefers medium_large when both are present
        #expect(result.listImageURL?.absoluteString == "https://example.com/medium_large.jpg")
    }

    // MARK: - Test 10: Hero boundary — size exactly at 2048px included in candidates

    @Test func heroBoundaryIncludesExactly2048Width() throws {
        let json = """
            {
              "source_url": "https://example.com/source.jpg",
              "media_details": {
                "sizes": {
                  "exactly_2048": { "source_url": "https://example.com/2048.jpg", "width": 2048, "height": 1365 },
                  "just_over": { "source_url": "https://example.com/over.jpg", "width": 2049, "height": 1366 }
                }
              }
            }
            """
        let media = try JSONDecoder().decode(WPDTO.Media.self, from: Data(json.utf8))
        let result = WPRestClient.resolveSizes(from: media)

        // just_over is filtered (2049 > 2048), so exactly_2048 wins
        #expect(result.heroImageURL?.absoluteString == "https://example.com/2048.jpg")
    }

    // MARK: - Test 11: Multiple sizes within valid range — picks the largest

    @Test func heroSelectsLargestWhenMultipleValidCandidates() throws {
        let json = """
            {
              "source_url": "https://example.com/source.jpg",
              "media_details": {
                "sizes": {
                  "small": { "source_url": "https://example.com/small.jpg", "width": 200, "height": 150 },
                  "medium": { "source_url": "https://example.com/medium.jpg", "width": 500, "height": 350 },
                  "large": { "source_url": "https://example.com/large.jpg", "width": 1200, "height": 800 },
                  "xl": { "source_url": "https://example.com/xl.jpg", "width": 1800, "height": 1200 }
                }
              }
            }
            """
        let media = try JSONDecoder().decode(WPDTO.Media.self, from: Data(json.utf8))
        let result = WPRestClient.resolveSizes(from: media)

        // All are <= 2048, xl (1800) is largest
        #expect(result.heroImageURL?.absoluteString == "https://example.com/xl.jpg")
    }

    // MARK: - Test 12: media_details present but sizes key absent entirely

    @Test func bothFallBackWhenSizesKeyAbsent() throws {
        let json = """
            {
              "source_url": "https://example.com/source.jpg",
              "media_details": {}
            }
            """
        let media = try JSONDecoder().decode(WPDTO.Media.self, from: Data(json.utf8))
        let result = WPRestClient.resolveSizes(from: media)

        #expect(result.listImageURL?.absoluteString == "https://example.com/source.jpg")
        #expect(result.heroImageURL?.absoluteString == "https://example.com/source.jpg")
    }
}

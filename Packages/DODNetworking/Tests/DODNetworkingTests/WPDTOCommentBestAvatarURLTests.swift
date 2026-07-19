import Foundation
import Testing

@testable import DODNetworking

@Suite("WPDTO.Comment bestAvatarURL property")
struct WPDTOCommentBestAvatarURLTests {
    @Test("returns nil when authorAvatarURLs is nil")
    func testReturnsNilWhenAvatarURLsIsNil() throws {
        let json = """
            {
                "id": 1,
                "post": 2
            }
            """
        let comment = try JSONDecoder().decode(WPDTO.Comment.self, from: Data(json.utf8))
        #expect(comment.bestAvatarURL == nil, "Expected bestAvatarURL to be nil when authorAvatarURLs is nil")
    }

    @Test("returns nil when authorAvatarURLs is an empty dictionary")
    func testReturnsNilWhenAuthorAvatarURLsIsEmpty() throws {
        let json = """
            {
                "id": 1,
                "post": 2,
                "author_avatar_urls": {}
            }
            """
        let comment = try JSONDecoder().decode(WPDTO.Comment.self, from: Data(json.utf8))
        #expect(comment.bestAvatarURL == nil, "Expected bestAvatarURL to be nil when authorAvatarURLs is empty")
    }

    @Test("returns the URL for '96' key when only '96' is present")
    func testReturnsURLFor96WhenOnly96IsPresent() throws {
        let json = """
            {
                "id": 1,
                "post": 2,
                "author_avatar_urls": {
                    "96": "https://example.com/96.png"
                }
            }
            """
        let comment = try JSONDecoder().decode(WPDTO.Comment.self, from: Data(json.utf8))
        #expect(
            comment.bestAvatarURL?.absoluteString == "https://example.com/96.png",
            "Expected bestAvatarURL to be the '96' URL"
        )
    }

    @Test("returns the URL for '48' key when only '48' is present (no '96')")
    func testReturnsURLFor48WhenOnly48IsPresent() throws {
        let json = """
            {
                "id": 1,
                "post": 2,
                "author_avatar_urls": {
                    "48": "https://example.com/48.png"
                }
            }
            """
        let comment = try JSONDecoder().decode(WPDTO.Comment.self, from: Data(json.utf8))
        #expect(
            comment.bestAvatarURL?.absoluteString == "https://example.com/48.png",
            "Expected bestAvatarURL to be the '48' URL"
        )
    }

    @Test("returns the URL for '24' key when only '24' is present (no '96' or '48')")
    func testReturnsURLFor24WhenOnly24IsPresent() throws {
        let json = """
            {
                "id": 1,
                "post": 2,
                "author_avatar_urls": {
                    "24": "https://example.com/24.png"
                }
            }
            """
        let comment = try JSONDecoder().decode(WPDTO.Comment.self, from: Data(json.utf8))
        #expect(
            comment.bestAvatarURL?.absoluteString == "https://example.com/24.png",
            "Expected bestAvatarURL to be the '24' URL"
        )
    }

    @Test("returns the '96' URL when multiple preferred sizes are present (both '96' and '48')")
    func testReturns96URLWhenMultiplePreferredSizesPresent() throws {
        let json = """
            {
                "id": 1,
                "post": 2,
                "author_avatar_urls": {
                    "96": "https://example.com/96.png",
                    "48": "https://example.com/48.png"
                }
            }
            """
        let comment = try JSONDecoder().decode(WPDTO.Comment.self, from: Data(json.utf8))
        #expect(
            comment.bestAvatarURL?.absoluteString == "https://example.com/96.png",
            "Expected bestAvatarURL to be the '96' URL (preferred over '48')"
        )
    }

    @Test("returns the non-preferred numeric key fallback when only '128' is present (none of 96/48/24)")
    func testReturns128URLWhenNonPreferredNumericKeyFallback() throws {
        let json = """
            {
                "id": 1,
                "post": 2,
                "author_avatar_urls": {
                    "128": "https://example.com/128.png"
                }
            }
            """
        let comment = try JSONDecoder().decode(WPDTO.Comment.self, from: Data(json.utf8))
        #expect(
            comment.bestAvatarURL?.absoluteString == "https://example.com/128.png",
            "Expected bestAvatarURL to be the '128' URL"
        )
    }

    @Test("returns the highest numeric key when multiple non-preferred sizes are present ('128' and '64')")
    func testReturnsHighestNumericKeyWhenMultipleNonPreferredSizesPresent() throws {
        let json = """
            {
                "id": 1,
                "post": 2,
                "author_avatar_urls": {
                    "128": "https://example.com/128.png",
                    "64": "https://example.com/64.png"
                }
            }
            """
        let comment = try JSONDecoder().decode(WPDTO.Comment.self, from: Data(json.utf8))
        #expect(
            comment.bestAvatarURL?.absoluteString == "https://example.com/128.png",
            "Expected bestAvatarURL to be the highest numeric key ('128' not '64')"
        )
    }

    @Test("returns the highest numeric key when non-numeric key mixed with numeric fallback ('thumb' and '200')")
    func testReturnsHighestNumericKeyWhenNonNumericKeyMixedWithNumericFallback() throws {
        let json = """
            {
                "id": 1,
                "post": 2,
                "author_avatar_urls": {
                    "thumb": "https://example.com/thumb.png",
                    "200": "https://example.com/200.png"
                }
            }
            """
        let comment = try JSONDecoder().decode(WPDTO.Comment.self, from: Data(json.utf8))
        #expect(
            comment.bestAvatarURL?.absoluteString == "https://example.com/200.png",
            "Expected bestAvatarURL to be the '200' URL (skipping non-numeric 'thumb')"
        )
    }
}

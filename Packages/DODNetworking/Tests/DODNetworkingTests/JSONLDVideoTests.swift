import DODDomain
import Foundation
import Testing

@testable import DODNetworking

/// DUT-214 — `mapVideo` must iterate a JSON-LD `video` array tolerantly:
/// `JSONSerialization` produces `[Any]`, so a `video` array mixing a valid
/// `VideoObject` dict with any non-dictionary element (a stray `@graph`
/// reference string, a heterogeneous ref) failed the whole-array
/// `[[String: Any]]` cast and silently dropped an otherwise-present video.
@Suite("JSONLDRecipeParser.mapVideo tolerant array (DUT-214)") struct JSONLDVideoTests {

    /// A leading non-dict string is skipped; the trailing `VideoObject` dict
    /// still resolves.
    @Test func recoversVideoFromHeterogeneousArrayWithLeadingString() {
        let raw: [Any] = [
            "#video",
            ["@type": "VideoObject", "contentUrl": "https://cdn.example.com/clip.mp4"],
        ]
        let video = JSONLDRecipeParser.mapVideo(raw)
        #expect(video?.url.absoluteString == "https://cdn.example.com/clip.mp4")
    }

    /// A stray number before the dict is likewise skipped.
    @Test func recoversVideoFromArrayWithStrayNumber() {
        let raw: [Any] = [
            42,
            ["@type": "VideoObject", "embedUrl": "https://cdn.example.com/embed"],
        ]
        let video = JSONLDRecipeParser.mapVideo(raw)
        #expect(video?.url.absoluteString == "https://cdn.example.com/embed")
    }

    /// A pure homogeneous dict array still resolves to its first element (no
    /// regression to the existing happy path).
    @Test func stillPicksFirstDictFromHomogeneousArray() {
        let raw: [Any] = [
            ["@type": "VideoObject", "contentUrl": "https://cdn.example.com/first.mp4"],
            ["@type": "VideoObject", "contentUrl": "https://cdn.example.com/second.mp4"],
        ]
        let video = JSONLDRecipeParser.mapVideo(raw)
        #expect(video?.url.absoluteString == "https://cdn.example.com/first.mp4")
    }

    /// An array with NO dictionary elements yields nil, not a crash.
    @Test func returnsNilWhenVideoArrayHasNoDictionaries() {
        #expect(JSONLDRecipeParser.mapVideo(["#video", 7, "https://x"] as [Any]) == nil)
    }
}

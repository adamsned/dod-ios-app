import DODDomain
import Foundation
import Testing

@testable import DODNetworking

/// Bug fix: `mapVideo` accepted ANY well-formed URL for `contentUrl`/
/// `embedUrl`, including a third-party webpage/embed-iframe URL that
/// `AVPlayer` can't decode. Confirmed live on `dutch-oven-7-can-soup`'s
/// JSON-LD, where BOTH `contentUrl` ("https://www.youtube.com/watch?v=...")
/// AND `embedUrl` ("https://www.youtube.com/embed/...") point to YouTube —
/// the recipe's Video section rendered, but `AVPlayer(url:)` silently failed
/// to load the YouTube page, leaving a permanently black player with AVKit's
/// disabled play icon (the user-visible bug: "the video doesn't play").
/// Compare `dutch-oven-hot-honey-butter-skillet-corn`, whose `contentUrl` is
/// a direct CDN `.mp4` and plays fine.
@Suite("JSONLDRecipeParser.mapVideo rejects non-playable embed hosts") struct JSONLDVideoPlayableHostTests {

    /// The exact shape confirmed live: both fields point to YouTube. Since
    /// neither is directly playable, the recipe has no usable video — nil,
    /// not a broken player.
    @Test func youtubeOnlyContentAndEmbedUrlYieldsNoVideo() {
        let raw: [String: Any] = [
            "@type": "VideoObject",
            "contentUrl": "https://www.youtube.com/watch?v=l9CjIEJBq4s",
            "embedUrl": "https://www.youtube.com/embed/l9CjIEJBq4s?feature=oembed",
        ]
        #expect(JSONLDRecipeParser.mapVideo(raw) == nil)
    }

    /// A direct CDN `contentUrl` (the working case) is unaffected by the
    /// host filter — self-hosted recipe video CDNs aren't on the blocklist.
    @Test func directCDNContentUrlStillResolves() {
        let raw: [String: Any] = [
            "@type": "VideoObject",
            "embedUrl": "https://video.mediavine.com/videos/abc123.js",
            "contentUrl": "https://videos.scriptwrapper.com/17055/abc123/original/video.mp4",
        ]
        let video = JSONLDRecipeParser.mapVideo(raw)
        #expect(video?.url.absoluteString == "https://videos.scriptwrapper.com/17055/abc123/original/video.mp4")
    }

    /// A YouTube `contentUrl` with no usable `embedUrl` fallback (only a
    /// vimeo one, also non-playable) still yields nil rather than picking
    /// whichever field happens to parse as a URL.
    @Test func nonPlayableContentUrlDoesNotFallBackToAnotherNonPlayableEmbedUrl() {
        let raw: [String: Any] = [
            "@type": "VideoObject",
            "contentUrl": "https://youtu.be/l9CjIEJBq4s",
            "embedUrl": "https://player.vimeo.com/video/12345",
        ]
        #expect(JSONLDRecipeParser.mapVideo(raw) == nil)
    }

    /// A non-playable `contentUrl` still correctly falls back to a genuinely
    /// playable `embedUrl` — the host filter doesn't disable the existing
    /// contentUrl-then-embedUrl fallback for the case where it's warranted.
    @Test func nonPlayableContentUrlFallsBackToPlayableEmbedUrl() {
        let raw: [String: Any] = [
            "@type": "VideoObject",
            "contentUrl": "https://www.youtube.com/watch?v=abc123",
            "embedUrl": "https://cdn.example.com/clip.mp4",
        ]
        let video = JSONLDRecipeParser.mapVideo(raw)
        #expect(video?.url.absoluteString == "https://cdn.example.com/clip.mp4")
    }
}

import DODDomain
import Foundation

/// The recipe `video` field, split out of ``JSONLDRecipeParser`` so the main
/// type stays under SwiftLint's `file_length`/`type_body_length` caps.
extension JSONLDRecipeParser {

    static func mapVideo(_ raw: Any?) -> RecipeVideo? {
        let dict: [String: Any]?
        if let object = raw as? [String: Any] {
            dict = object
        } else if let array = raw as? [Any] {
            // DUT-214: `raw as? [[String: Any]]` succeeds only when EVERY element
            // is a dictionary, so a `video` array mixing a `VideoObject` dict with
            // any non-dict element (a stray `"#video"` graph reference, a
            // heterogeneous `@graph` ref) failed the whole-array cast and silently
            // dropped the video. Cast to `[Any]` and recover the first dictionary
            // element, skipping non-dictionaries.
            dict = array.compactMap { $0 as? [String: Any] }.first
        } else {
            dict = nil
        }
        guard let dict else { return nil }

        // contentUrl is preferred; fall back to embedUrl. Resolve each
        // candidate to a `URL` before falling back — a scraped `contentUrl`
        // that is present but blank/malformed (e.g. `"contentUrl": ""`) must
        // not win the `??` and swallow a perfectly good `embedUrl`, dropping
        // the whole video for a field that only LOOKS populated.
        //
        // Bug fix: a candidate URL must also be a DIRECTLY PLAYABLE media
        // resource, not a third-party webpage/embed-iframe URL — `AVPlayer`
        // can't decode a YouTube `watch`/`embed` page (or the equivalent on
        // other embed platforms) and silently fails to load, which AVKit
        // renders as a permanently broken black player with a disabled play
        // icon. Some sites' schema.org markup populates BOTH `contentUrl`
        // AND `embedUrl` with a YouTube URL (confirmed live on
        // dutch-oven-7-can-soup — schema.org's spec says `contentUrl` should
        // be the raw file, but real-world JSON-LD doesn't always follow
        // that), so filtering only `embedUrl` isn't enough; both candidates
        // are checked here. When neither survives, treat the recipe as
        // having no playable video (nil) rather than showing a dead player —
        // the same UX as a recipe that never had a `video` field at all.
        let url = Self.playableVideoURL(dict["contentUrl"]) ?? Self.playableVideoURL(dict["embedUrl"])
        guard let url else { return nil }

        let thumbnail =
            (dict["thumbnailUrl"] as? String).flatMap { URL(string: $0) }
            ?? ((dict["thumbnailUrl"] as? [Any])?.compactMap { $0 as? String }.first)
            .flatMap { URL(string: $0) }

        let duration = parseISO8601Duration(dict["duration"] as? String)

        return RecipeVideo(url: url, thumbnailURL: thumbnail, duration: duration)
    }

    /// Hosts known to serve only a webpage or iframe-embed for their videos —
    /// never a direct, `AVPlayer`-playable media file — at the URLs a
    /// recipe's JSON-LD would plausibly put in `contentUrl`/`embedUrl`.
    /// Self-hosted recipe videos (a site's own CDN, e.g. Mediavine/
    /// ScriptWrapper) aren't on this list and are assumed playable.
    private static let nonDirectlyPlayableVideoHosts: Set<String> = [
        "youtube.com", "www.youtube.com", "m.youtube.com", "youtu.be",
        "vimeo.com", "www.vimeo.com", "player.vimeo.com",
        "dailymotion.com", "www.dailymotion.com",
        "tiktok.com", "www.tiktok.com",
        "instagram.com", "www.instagram.com",
        "facebook.com", "www.facebook.com", "fb.watch",
    ]

    /// Resolves a raw JSON-LD string field to a `URL`, or nil if it's blank/
    /// malformed/unparseable OR resolves to a known non-directly-playable
    /// host (see ``nonDirectlyPlayableVideoHosts``).
    private static func playableVideoURL(_ raw: Any?) -> URL? {
        guard let string = raw as? String, let url = URL(string: string) else { return nil }
        guard let host = url.host?.lowercased() else { return url }
        return nonDirectlyPlayableVideoHosts.contains(host) ? nil : url
    }
}

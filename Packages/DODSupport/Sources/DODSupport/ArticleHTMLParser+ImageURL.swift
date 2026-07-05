import Foundation

/// DUT-582 — lazy-load image-URL resolution for ``ArticleHTMLParser``.
///
/// Split out of `ArticleHTMLParser.swift` to hold that file under the 400-line
/// file-length cap. Dutch Oven Daddy is WordPress with a lazy-load plugin, so an
/// `<img>`'s `src` is a `data:` URI or a 1px spacer placeholder and the real
/// photo URL lives in `data-src` / `data-lazy-src` (single) or `srcset` /
/// `data-lazy-srcset` (candidate list). ``ReliableImage`` needs an absolute
/// `http(s)` URL, so these helpers resolve one.
extension ArticleHTMLParser {

    /// Resolve a usable absolute `http(s)` image URL from an `<img>` tag, or nil.
    ///
    /// 1. Single-URL candidates in priority order `data-src`, `data-lazy-src`,
    ///    `src` — the first that is non-empty and not a `data:`/placeholder wins.
    /// 2. Otherwise the largest candidate from `srcset` / `data-lazy-srcset`
    ///    (the last entry: WP emits ascending widths, so the last is the widest).
    /// 3. The chosen raw value is entity-decoded then normalized to an absolute
    ///    `http(s)` URL against `baseURL` (protocol-relative `//` → `https:`,
    ///    root-/relative → resolved against the base, absolute → as-is).
    static func imageURL<S: StringProtocol>(fromTag tagBody: S, baseURL: URL?) -> URL? {
        for attribute in ["data-src", "data-lazy-src", "src"] {
            let candidate = attributeValue(attribute, in: tagBody)
            if isUsableImageSource(candidate) {
                return normalizedImageURL(candidate, baseURL: baseURL)
            }
        }
        // No usable single src — fall back to the largest `srcset` candidate.
        for attribute in ["data-lazy-srcset", "srcset"] {
            let list = attributeValue(attribute, in: tagBody)
            if let widest = largestSrcsetCandidate(list), isUsableImageSource(widest) {
                return normalizedImageURL(widest, baseURL: baseURL)
            }
        }
        return nil
    }

    /// Whether a raw `src`-style value is a real image URL rather than a
    /// lazy-load placeholder — non-empty, not a `data:` URI (inline spacer /
    /// blank), and not a known 1px spacer GIF name.
    private static func isUsableImageSource(_ raw: String) -> Bool {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return false }
        let lowered = value.lowercased()
        if lowered.hasPrefix("data:") { return false }
        // Common lazy-load spacer filenames the plugins swap into `src`.
        for spacer in ["spacer.gif", "blank.gif", "placeholder.svg", "lazy-placeholder"]
        where lowered.contains(spacer) {
            return false
        }
        return true
    }

    /// The widest URL in a `srcset`-style `url widthDescriptor, …` list, or nil.
    /// WP emits candidates in ascending width, so the LAST entry is the widest.
    private static func largestSrcsetCandidate(_ srcset: String) -> String? {
        let candidates =
            srcset
            .split(separator: ",")
            .compactMap { entry -> String? in
                // Each entry is `URL 480w` (or `URL 2x`, or bare `URL`); the URL
                // is the first whitespace-delimited token.
                let url = entry.trimmingCharacters(in: .whitespacesAndNewlines)
                    .split(whereSeparator: { $0.isWhitespace })
                    .first
                return url.map(String.init)
            }
            .filter { !$0.isEmpty }
        return candidates.last
    }

    /// Entity-decode `raw` and resolve it to an absolute `http(s)` URL:
    /// protocol-relative (`//host/x`) gets `https:` prepended; root-/relative
    /// values resolve against `baseURL`; already-absolute values pass through.
    private static func normalizedImageURL(_ raw: String, baseURL: URL?) -> URL? {
        let decoded = HTMLSanitizer.decodingEntities(raw).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !decoded.isEmpty else { return nil }
        if decoded.hasPrefix("//") {
            return URL(string: "https:" + decoded)
        }
        if decoded.lowercased().hasPrefix("http://") || decoded.lowercased().hasPrefix("https://") {
            return URL(string: decoded)
        }
        // Root-relative (`/wp-content/…`) or other relative — resolve against the
        // page's base URL when we have one; without a base a relative value can't
        // become the absolute URL ReliableImage needs, so drop it.
        guard let baseURL else { return nil }
        return URL(string: decoded, relativeTo: baseURL)?.absoluteURL
    }
}

import Foundation

/// A single rendered block of a WordPress article body, produced by
/// ``ArticleHTMLParser/parse(html:)`` and rendered in document order. The v1.x
/// rich replacement for the plain-text ``ArticleBodyExtractor``, which
/// collapsed round-up posts into one unreadable text wall.
public enum ArticleBlock: Equatable, Sendable {
    /// `<h1>`…`<h6>`; `level` is clamped to `1...6`.
    case heading(level: Int, text: AttributedString)
    /// A `<p>` (or `<blockquote>`, rendered as a paragraph).
    case paragraph(AttributedString)
    /// An `<img>` (optionally in `<figure>`); caption = `<figcaption>` else `alt`.
    case image(url: URL, caption: String?)
    /// A `<ul>` (`ordered: false`) / `<ol>` (`ordered: true`), one item per `<li>`.
    case list(ordered: Bool, items: [AttributedString])
}

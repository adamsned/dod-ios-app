import Foundation
import Testing

@testable import DODSupport

/// DUT-437 — comments must be stripped BEFORE the entry-content boundary scan:
/// `sliceUntilMatchingClose` counts `<div`/`</div>` with no comment awareness,
/// so a comment carrying either token corrupted the slice (truncated article,
/// or page chrome swallowed into it). Split from `ArticleHTMLParserTests` for
/// the SwiftLint `type_body_length` cap.
@Suite("ArticleHTMLParser comment-vs-boundary (DUT-437)")
struct ArticleHTMLParserCommentBoundaryTests {

    private func paragraphTexts(_ html: String) -> [String] {
        ArticleHTMLParser.parse(html: html).compactMap { block -> String? in
            guard case .paragraph(let body) = block else { return nil }
            return String(body.characters)
        }
    }

    /// A comment carrying `</div>` inside the entry-content used to terminate
    /// the depth-tracked slice early — everything after it silently vanished.
    @Test func commentWithClosingDivDoesNotTruncateTheArticle() {
        let page = """
            <html><body><div class="entry-content">
            <p>Before the comment.</p>
            <!-- <div class="ad-slot">commented-out ad</div> end </div> marker -->
            <p>After the comment.</p>
            </div><footer>chrome</footer></body></html>
            """
        let texts = paragraphTexts(page)
        #expect(texts.contains("Before the comment."))
        #expect(texts.contains("After the comment."))
        #expect(!texts.contains("chrome"))
    }

    /// An unpaired `<div` inside a comment used to inflate the depth count so
    /// the slice swallowed post-article page chrome.
    @Test func commentWithUnpairedOpenDivDoesNotSwallowPageChrome() {
        let page = """
            <html><body><div class="entry-content">
            <p>Article prose.</p>
            <!-- <div id="never-closed" -->
            </div><p>chrome paragraph outside the article</p></body></html>
            """
        let texts = paragraphTexts(page)
        #expect(texts.contains("Article prose."))
        #expect(!texts.contains("chrome paragraph outside the article"))
    }
}

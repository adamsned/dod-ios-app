import Foundation
import Testing

@testable import DODSupport

/// DUT-655 coverage: nested `<li>` lists no longer collapse, and a
/// multi-paragraph `<blockquote>` splits into one paragraph per `<p>`.
@Suite("ArticleHTMLParser blocks (DUT-655)")
struct ArticleHTMLParserBlocksTests {

    private func text(_ value: AttributedString) -> String { String(value.characters) }

    // MARK: - Nested lists

    /// A `<ul>` whose first `<li>` contains a nested `<ul>` used to collapse:
    /// the old first-`</li>` slice stopped at the FIRST nested `</li>`, cutting
    /// the outer item short and re-scanning the nested items as top-level
    /// siblings. Depth-tracked `<li>` slicing keeps ONE list block whose first
    /// item folds its nested prose inline.
    @Test func nestedListDoesNotCollapse() {
        let html = "<ul><li>Dry rub<ul><li>salt</li><li>pepper</li></ul></li><li>Wet brine</li></ul>"
        let blocks = ArticleHTMLParser.parse(html: html)
        #expect(blocks.count == 1)
        guard case .list(let ordered, let items) = blocks.first else {
            Issue.record("expected one list block, got \(blocks)")
            return
        }
        #expect(ordered == false)
        // Two TOP-LEVEL items — the nested salt/pepper are not siblings.
        #expect(items.count == 2)
        #expect(text(items[0]).contains("Dry rub"))
        #expect(text(items[0]).contains("salt"))
        #expect(text(items[0]).contains("pepper"))
        #expect(text(items[1]) == "Wet brine")
    }

    // MARK: - Multi-paragraph blockquote

    /// A `<blockquote>` wrapping several `<p>` children previously rendered as
    /// one run-on paragraph. It now emits ONE `.paragraph` per inner `<p>`.
    @Test func blockquoteWithMultipleParagraphsSplits() {
        let html = "<blockquote><p>First line of the quote.</p><p>Second line of the quote.</p></blockquote>"
        let blocks = ArticleHTMLParser.parse(html: html)
        #expect(blocks.count == 2)
        guard case .paragraph(let first) = blocks.first, case .paragraph(let second) = blocks.last else {
            Issue.record("expected two paragraph blocks, got \(blocks)")
            return
        }
        #expect(text(first) == "First line of the quote.")
        #expect(text(second) == "Second line of the quote.")
    }

    /// A `<blockquote>` with no `<p>` children still yields a single paragraph
    /// over its inline body (unchanged behavior).
    @Test func blockquoteWithoutParagraphsStaysSingle() {
        let blocks = ArticleHTMLParser.parse(html: "<blockquote>A bare quote.</blockquote>")
        #expect(blocks.count == 1)
        guard case .paragraph(let body) = blocks.first else {
            Issue.record("expected one paragraph, got \(blocks)")
            return
        }
        #expect(text(body) == "A bare quote.")
    }
}

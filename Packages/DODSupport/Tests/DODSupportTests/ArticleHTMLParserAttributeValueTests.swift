import Testing

@testable import DODSupport

// MARK: - ArticleHTMLParser.attributeValue(_:in:) Tests
//
// Comprehensive test coverage for parameterized attribute extraction with
// case-insensitive matching, word-boundary checking (src vs srcset), and
// quoted-value-only parsing (no unquoted fallback).

struct ArticleHTMLParserAttributeValueTests {

    // MARK: - Basic Extraction (Double & Single Quotes)

    @Test("Basic double-quoted attribute extraction")
    func basicDoubleQuoted() {
        let result = ArticleHTMLParser.attributeValue("src", in: "src=\"image.jpg\"")
        #expect(result == "image.jpg")
    }

    @Test("Basic single-quoted attribute extraction")
    func basicSingleQuoted() {
        let result = ArticleHTMLParser.attributeValue("src", in: "src='image.jpg'")
        #expect(result == "image.jpg")
    }

    // MARK: - Word-Boundary Enforcement (Critical: src vs srcset)

    @Test("srcset is rejected when src is requested (word-boundary check)")
    func srcVsSrcset() {
        let result = ArticleHTMLParser.attributeValue("src", in: "srcset=\"foo.jpg\"")
        #expect(result.isEmpty)
    }

    @Test("Finds real src after rejecting srcset candidate")
    func srcFoundAfterSrcsetRejection() {
        let result = ArticleHTMLParser.attributeValue("src", in: "srcset=\"ignored.jpg\" src=\"real.jpg\"")
        #expect(result == "real.jpg")
    }

    // MARK: - Case Insensitivity

    @Test("Uppercase attribute name matches lowercase in tag")
    func caseInsensitiveUppercase() {
        let result = ArticleHTMLParser.attributeValue("SRC", in: "src=\"image.jpg\"")
        #expect(result == "image.jpg")
    }

    // MARK: - Whitespace Handling

    @Test("Whitespace around equals sign is accepted")
    func whitespaceAroundEquals() {
        let result = ArticleHTMLParser.attributeValue("src", in: "src  =  \"spaced.jpg\"")
        #expect(result == "spaced.jpg")
    }

    // MARK: - Quote Termination (Absence = Empty, Not Fallback)

    @Test("Unterminated quote returns empty string")
    func unterminatedQuote() {
        let result = ArticleHTMLParser.attributeValue("src", in: "src=\"unclosed")
        #expect(result.isEmpty)
    }

    @Test("No quote after equals returns empty (no unquoted fallback)")
    func noQuoteAfterEquals() {
        let result = ArticleHTMLParser.attributeValue("src", in: "src=unquoted")
        #expect(result.isEmpty)
    }

    // MARK: - Attribute Absence

    @Test("Absent attribute returns empty string")
    func attributeAbsent() {
        let result = ArticleHTMLParser.attributeValue("src", in: "class=\"foo\" alt=\"bar\"")
        #expect(result.isEmpty)
    }

    @Test("Empty tag body returns empty string")
    func emptyTagBody() {
        let result = ArticleHTMLParser.attributeValue("src", in: "")
        #expect(result.isEmpty)
    }

    // MARK: - Multiple Attributes (Correct Extraction)

    @Test("Extracts requested attribute when multiple are present")
    func multipleAttributesExtractRequested() {
        let result = ArticleHTMLParser.attributeValue("alt", in: "src=\"image.jpg\" alt=\"A description\"")
        #expect(result == "A description")
    }
}

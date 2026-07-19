import Testing

@testable import DODSupport

@Suite("ArticleHTMLParser.idAttributeValue")
struct ArticleHTMLParserIdAttributeValueTests {

    @Test("Double-quoted value")
    func doubleQuotedValue() {
        let result = ArticleHTMLParser.idAttributeValue(attributes: "class=\"foo\" id=\"my-id\"")
        #expect(result == "my-id")
    }

    @Test("Single-quoted value")
    func singleQuotedValue() {
        let result = ArticleHTMLParser.idAttributeValue(attributes: "id='my-id'")
        #expect(result == "my-id")
    }

    @Test("Unquoted value (read to next whitespace)")
    func unquotedValue() {
        let result = ArticleHTMLParser.idAttributeValue(attributes: "id=my-id")
        #expect(result == "my-id")
    }

    @Test("Whitespace around equals sign")
    func whitespaceAroundEquals() {
        let result = ArticleHTMLParser.idAttributeValue(attributes: "id  =  'spaced'")
        #expect(result == "spaced")
    }

    @Test("id attribute at start of string (no boundary check needed)")
    func idAtStartOfString() {
        let result = ArticleHTMLParser.idAttributeValue(attributes: "id=\"first\"")
        #expect(result == "first")
    }

    @Test("Rejects data-id (false positive, no real id follows)")
    func rejectsDataIdFalsePositive() {
        let result = ArticleHTMLParser.idAttributeValue(attributes: "data-id=\"nope\"")
        #expect(result == nil)
    }

    @Test("Rejects grid and valid (substrings in class, no id attribute)")
    func rejectsSubstringsInClass() {
        let result = ArticleHTMLParser.idAttributeValue(attributes: "class=\"grid valid\"")
        #expect(result == nil)
    }

    @Test("CRITICAL: Continues scanning past rejected data-id to find real id")
    func continuesAfterRejectedCandidate() {
        let result = ArticleHTMLParser.idAttributeValue(attributes: "data-id=\"nope\" id=\"real\"")
        #expect(result == "real")
    }

    @Test("Unclosed quote returns nil")
    func unclosedQuote() {
        let result = ArticleHTMLParser.idAttributeValue(attributes: "id=\"unclosed")
        #expect(result == nil)
    }

    @Test("Case-insensitive attribute name (ID vs id)")
    func caseInsensitiveAttributeName() {
        let result = ArticleHTMLParser.idAttributeValue(attributes: "ID=\"upper\"")
        #expect(result == "upper")
    }

    @Test("No id attribute present")
    func noIdAttribute() {
        let result = ArticleHTMLParser.idAttributeValue(attributes: "class=\"foo\" data-x=\"y\"")
        #expect(result == nil)
    }

    @Test("Empty attribute string")
    func emptyAttributeString() {
        let result = ArticleHTMLParser.idAttributeValue(attributes: "")
        #expect(result == nil)
    }

    @Test("Mixed quotes in same string (id uses single, class uses double)")
    func mixedQuoteStyles() {
        let result = ArticleHTMLParser.idAttributeValue(attributes: "class=\"container\" id='content'")
        #expect(result == "content")
    }

    @Test("Unquoted value with multiple words stops at first whitespace")
    func unquotedMultipleWords() {
        let result = ArticleHTMLParser.idAttributeValue(attributes: "id=my-id class=\"other\"")
        #expect(result == "my-id")
    }

    @Test("Attribute value with special characters and numbers")
    func specialCharactersAndNumbers() {
        let result = ArticleHTMLParser.idAttributeValue(attributes: "id='section-2-body'")
        #expect(result == "section-2-body")
    }

    @Test("Multiple spaces before equals sign")
    func multipleSpacesBeforeEquals() {
        let result = ArticleHTMLParser.idAttributeValue(attributes: "id    =\"value\"")
        #expect(result == "value")
    }
}

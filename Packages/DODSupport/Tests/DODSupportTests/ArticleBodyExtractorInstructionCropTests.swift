import Testing

@testable import DODSupport

/// L1 unit tests for the DUT-573 / CL-313 instruction-heading crop on
/// ``ArticleBodyExtractor/croppingBeforeInstructionHeading(_:)`` and its
/// effect inside ``ArticleBodyExtractor/extractRecipeBlurb(html:paragraphLimit:)``.
///
/// The full pre-recipe-card body on most posts includes the author's
/// step-by-step "how to make" walkthrough, which duplicates the Instructions
/// section rendered below (AC-4.3). The crop drops that walkthrough while
/// keeping the intro story + tips paragraphs that precede it.
///
/// Spec trace: DUT-573 (follow-up to DUT-572), CL-313. Separate file from the
/// main suites to keep each under SwiftLint's `type_body_length` cap.
@Suite("ArticleBodyExtractor.croppingBeforeInstructionHeading (DUT-573 / CL-313)")
struct ArticleBodyExtractorInstructionCropTests {

    /// Crops at a `<h2>How to Make X</h2>` heading — keeps the intro paragraph
    /// before it, drops the heading and everything after.
    @Test func cropsAtHowToMakeH2() {
        let html = """
            <p>The intro story about this stew.</p>
            <h2>How to Make Beef Stew</h2>
            <p>Step one: brown the beef.</p>
            <p>Step two: simmer.</p>
            """
        let result = ArticleBodyExtractor.croppingBeforeInstructionHeading(html)
        #expect(result.contains("The intro story"))
        #expect(!result.contains("How to Make"))
        #expect(!result.contains("Step one"))
        #expect(!result.contains("Step two"))
    }

    /// Crops at a `<h3>Instructions</h3>` heading.
    @Test func cropsAtInstructionsH3() {
        let html = """
            <p>A little backstory.</p>
            <h3>Instructions</h3>
            <p>Do the thing.</p>
            """
        let result = ArticleBodyExtractor.croppingBeforeInstructionHeading(html)
        #expect(result.contains("A little backstory"))
        #expect(!result.contains("Instructions"))
        #expect(!result.contains("Do the thing"))
    }

    /// No-op when there is no instruction-section heading — the input is
    /// returned unchanged, including a non-matching heading.
    @Test func noOpWhenNoInstructionHeading() {
        let html = """
            <p>Intro.</p>
            <h2>Why You'll Love This</h2>
            <p>Because it is cozy.</p>
            """
        let result = ArticleBodyExtractor.croppingBeforeInstructionHeading(html)
        #expect(result == html)
    }

    /// Case-insensitive — a lowercase / mixed-case heading still crops.
    @Test func caseInsensitiveMatch() {
        let html = """
            <p>Intro paragraph.</p>
            <h2>HOW TO MAKE It</h2>
            <p>walkthrough</p>
            """
        let result = ArticleBodyExtractor.croppingBeforeInstructionHeading(html)
        #expect(result.contains("Intro paragraph"))
        #expect(!result.contains("walkthrough"))
    }

    /// Keeps ALL intro paragraphs (including a "why you'll love it" section)
    /// that precede the instruction heading, dropping only from the heading on.
    @Test func keepsIntroParagraphsBeforeHeading() {
        let html = """
            <p>Paragraph one.</p>
            <h2>Why You'll Love This Recipe</h2>
            <p>Paragraph two — the tips.</p>
            <h2>Step by Step</h2>
            <p>Paragraph three — the walkthrough.</p>
            """
        let result = ArticleBodyExtractor.croppingBeforeInstructionHeading(html)
        #expect(result.contains("Paragraph one"))
        #expect(result.contains("Why You'll Love This Recipe"))
        #expect(result.contains("Paragraph two"))
        #expect(!result.contains("Step by Step"))
        #expect(!result.contains("Paragraph three"))
    }

    /// Strips nested tags inside the heading before matching (e.g. a `<span>`
    /// wrapper WordPress themes add around heading text).
    @Test func stripsNestedTagsInHeading() {
        let html = """
            <p>Intro.</p>
            <h2><span class="x">Directions</span></h2>
            <p>steps here</p>
            """
        let result = ArticleBodyExtractor.croppingBeforeInstructionHeading(html)
        #expect(result.contains("Intro"))
        #expect(!result.contains("steps here"))
    }

    /// End-to-end through `extractRecipeBlurb`: the crop runs between the WPRM
    /// crop and the paragraph cap, so the walkthrough after a "How to Make"
    /// heading is dropped even before the card boundary.
    @Test func extractRecipeBlurbDropsWalkthrough() {
        let html = """
            <html><body>
            <div class="entry-content">
            <p>The intro story.</p>
            <h2>How to Make This</h2>
            <p>Walkthrough step that duplicates instructions.</p>
            <div class="wprm-recipe-container"><p>card</p></div>
            </div>
            </body></html>
            """
        let result = ArticleBodyExtractor.extractRecipeBlurb(html: html, paragraphLimit: .max)
        #expect(result.contains("The intro story"))
        #expect(!result.contains("How to Make This"))
        #expect(!result.contains("Walkthrough step"))
        #expect(!result.contains("card"))
    }
}

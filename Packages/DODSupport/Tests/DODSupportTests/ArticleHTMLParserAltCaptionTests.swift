import Foundation
import Testing

@testable import DODSupport

/// DUT-918 — the article renderer used the image `alt` attribute as a visible
/// caption when there was no `<figcaption>`. DOD's `alt` texts are internal
/// Pinterest / "social media" production notes, so they leaked as on-screen
/// captions across ~40 recipes (Sweet Potato Hash, Philly Cheesesteak, Steamed
/// Artichokes, Skillet Fried Potatoes, …). Visible captions now come from
/// `<figcaption>` ONLY; `alt` is accessibility text, never a reader caption.
@Suite("ArticleHTMLParser drops alt-as-caption (DUT-918)")
struct ArticleHTMLParserAltCaptionTests {

    private func firstImageCaption(_ html: String) -> String?? {
        let blocks = ArticleHTMLParser.parse(html: html, baseURL: URL(string: "https://x.test"))
        for block in blocks {
            if case .image(_, let caption) = block { return caption }
        }
        return nil  // no image block found
    }

    @Test func figureWithoutFigcaptionDropsTheAltNote() {
        // The exact leak Ned hit on device: a social-media share image whose
        // only caption source is an internal `alt`.
        let html = """
            <figure><img src="/social.jpg" alt="Social media image for Philly Cheesesteak Skillet."></figure>
            """
        #expect(firstImageCaption(html) == .some(nil))
    }

    @Test func standaloneImgDropsTheAltNote() {
        let html = #"<img src="/one.jpg" alt="One photo for social media for Sweet Potato Hash.">"#
        #expect(firstImageCaption(html) == .some(nil))
    }

    @Test func realFigcaptionIsStillShown() {
        // A genuine reader caption in `<figcaption>` survives.
        let html = """
            <figure><img src="/dish.jpg" alt="alt text ignored">\
            <figcaption>The finished skillet, ready to serve.</figcaption></figure>
            """
        #expect(firstImageCaption(html) == .some("The finished skillet, ready to serve."))
    }
}

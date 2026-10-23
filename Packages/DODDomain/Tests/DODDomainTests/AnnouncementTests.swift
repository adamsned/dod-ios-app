import Foundation
import Testing

@testable import DODDomain

@Suite("Announcement (DUT-147)")
struct AnnouncementTests {
    @Test func deepLinkShop() {
        let url = URL(string: "https://buzzywaxx.com/shop")!
        #expect(Announcement.DeepLink(url: url) == .shop(url))
    }

    @Test func deepLinkRecipe() {
        let url = URL(string: "https://www.dutchovendaddy.com/dutch-oven-awesome-chili/")!
        #expect(Announcement.DeepLink(url: url) == .recipe(url))
    }

    @Test func deepLinkTipJar() {
        let url = URL(string: "https://www.dutchovendaddy.com/tip-jar/")!
        #expect(Announcement.DeepLink(url: url) == .tipJar)
    }

    @Test func deepLinkNil() {
        let url = URL(string: "https://example.com/x")!
        #expect(Announcement.DeepLink(url: url) == nil)
    }
}

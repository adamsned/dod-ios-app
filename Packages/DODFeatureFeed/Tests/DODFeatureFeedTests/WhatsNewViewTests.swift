import Testing

@testable import DODFeatureFeed

@Suite("WhatsNewView") struct WhatsNewViewTests {
    @Test func visibleBulletsCapsAtFive() {
        let bullets = (1...7).map { "b\($0)" }
        #expect(WhatsNewView.visibleBullets(bullets) == ["b1", "b2", "b3", "b4", "b5"])
    }

    @Test func visibleBulletsKeepsShortLists() {
        let bullets = ["a", "b", "c"]
        #expect(WhatsNewView.visibleBullets(bullets) == bullets)
    }
}

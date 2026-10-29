import Testing

@testable import DODFeatureRecipeDetail

@MainActor final class FakeBrightnessController: ScreenBrightnessController {
    var brightness: Double = 0.3
}

@MainActor @Suite("Campfire session") struct CampfireSessionTests {

    @Test func toggleVariantSwitchesDayNight() {
        let session = CampfireSession(brightness: FakeBrightnessController())
        #expect(session.variant == .day)
        session.toggleVariant()
        #expect(session.variant == .night)
    }

    @Test func enterSetsMaxBrightness() {
        let fake = FakeBrightnessController()
        let session = CampfireSession(brightness: fake)
        session.enter()
        #expect(fake.brightness == 1.0)
        #expect(session.isActive)
    }

    @Test func exitRestoresOriginal() {
        let fake = FakeBrightnessController()
        let session = CampfireSession(brightness: fake)
        session.enter()
        session.exit()
        #expect(fake.brightness == 0.3)
        #expect(!session.isActive)
    }

    @Test func doubleEnterKeepsOriginal() {
        let fake = FakeBrightnessController()
        let session = CampfireSession(brightness: fake)
        session.enter()
        session.enter()
        session.exit()
        #expect(fake.brightness == 0.3)
    }

    @Test func exitWithoutEnterIsNoOp() {
        let fake = FakeBrightnessController()
        CampfireSession(brightness: fake).exit()
        #expect(fake.brightness == 0.3)
    }

    @Test func toggleFlipsActive() {
        let fake = FakeBrightnessController()
        let session = CampfireSession(brightness: fake)
        session.toggle()
        #expect(session.isActive)
        session.toggle()
        #expect(!session.isActive)
        #expect(fake.brightness == 0.3)
    }
}

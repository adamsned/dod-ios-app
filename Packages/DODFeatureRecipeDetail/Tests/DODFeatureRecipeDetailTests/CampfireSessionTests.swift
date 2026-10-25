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
}

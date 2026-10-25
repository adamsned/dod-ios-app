import Testing

@testable import DODFeatureRecipeDetail

@MainActor
@Suite("CookModeViewModel doneness coach (DUT-1003)") struct CookModeViewModelDonenessTests {
    @Test func donenessCoachDefaultsToUnavailable() {
        #expect(CookModeViewModelTests.makeViewModel(stepCount: 2).donenessCoach.isAvailable == false)
    }
}

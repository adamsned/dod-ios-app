import Testing

@testable import DODFeatureRecipeDetail

@MainActor
@Suite("Cook Mode kid-safe badge (DUT-2044)") struct CookModeKidBadgeTests {

    @Test func badgeTextIsStable() {
        #expect(CookModeView.kidSafeBadgeText == "Kids can help with this one")
    }
}

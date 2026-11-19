import Testing

@testable import DODFeatureRecipeDetail

@Test func rosterHeadsUpBannerIsEmptyWithEmptyInputs() {
    let banner = RosterHeadsUpBanner(warnings: [], portionMessage: nil)
    #expect(banner.isEmpty == true)
}

@Test func rosterHeadsUpBannerIsNotEmptyWithWarning() {
    let banner = RosterHeadsUpBanner(warnings: ["Contains dairy - flagged for Emma"], portionMessage: nil)
    #expect(banner.isEmpty == false)
}

@Test func rosterHeadsUpBannerIsNotEmptyWithPortionMessage() {
    let banner = RosterHeadsUpBanner(warnings: [], portionMessage: "Serves 4 people")
    #expect(banner.isEmpty == false)
}

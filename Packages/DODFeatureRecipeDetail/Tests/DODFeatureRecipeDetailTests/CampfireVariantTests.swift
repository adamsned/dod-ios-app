import Testing

@testable import DODFeatureRecipeDetail

struct CampfireVariantTests {
    @Test func toggledFlipsBetweenDayAndNight() {
        #expect(CampfireVariant.day.toggled == .night)
        #expect(CampfireVariant.night.toggled == .day)
    }

    @Test func xxlSizesExceedBodyScale() {
        #expect(CampfireVariant.stepFontSize >= 40)
        #expect(CampfireVariant.navButtonHeight >= 88)
    }

    @Test func labels() {
        #expect(CampfireVariant.day.label == "Day")
        #expect(CampfireVariant.night.label == "Night")
    }
}

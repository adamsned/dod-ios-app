import Foundation
import Testing

@testable import DODSupport

@Test func twoItems() {
    let result = SpokenPreflight.script(title: "Test Recipe", equipment: ["item1", "item2"], coals: nil)
    #expect(result == "For Test Recipe you need item1 and item2.")
}

@Test func threeItems() {
    let result = SpokenPreflight.script(title: "Test Recipe", equipment: ["item1", "item2", "item3"], coals: nil)
    #expect(result == "For Test Recipe you need item1, item2, and item3.")
}

@Test func emptyOrBlankEquipmentUsesFallbackGear() {
    let result = SpokenPreflight.script(title: "Test Recipe", equipment: ["", "   "], coals: nil)
    #expect(result.contains("chimney starter"))
}

@Test func charcoalRecommendationIncluded() {
    let recommendation = CharcoalRecommendation(totalBriquettes: 24, bottom: 8, top: 16, refreshIntervalMinutes: 45)
    let result = SpokenPreflight.script(title: "Test Recipe", equipment: ["item1"], coals: recommendation)
    #expect(result.contains("about 24 briquettes"))
    #expect(result.contains("8 under the oven"))
    #expect(result.contains("16 on the lid"))
}

@Test func noBriquettesWhenNilOrZero() {
    let result1 = SpokenPreflight.script(title: "Test Recipe", equipment: ["item1"], coals: nil)
    #expect(!result1.contains("briquettes"))

    let result2 = SpokenPreflight.script(
        title: "Test Recipe",
        equipment: ["item1"],
        coals: CharcoalRecommendation(totalBriquettes: 0, bottom: 0, top: 0, refreshIntervalMinutes: 45)
    )
    #expect(!result2.contains("briquettes"))
}

@Test func noEmDash() {
    let result = SpokenPreflight.script(title: "Test Recipe", equipment: ["item1"], coals: nil)
    #expect(!result.contains("\u{2014}"))
}

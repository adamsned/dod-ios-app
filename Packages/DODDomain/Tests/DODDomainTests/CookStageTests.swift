import Foundation
import Testing

@testable import DODDomain

@Suite("CookStage")
struct CookStageTests {
    @Test func codableRoundTrip() throws {
        let data = try JSONEncoder().encode(CookStage.kitchenPrep)
        let decoded = try JSONDecoder().decode(CookStage.self, from: data)
        #expect(decoded == .kitchenPrep)
    }

    @Test func rawValuesAreStable() {
        #expect(CookStage.kitchenPrep.rawValue == "kitchenPrep")
        #expect(CookStage.campfireFinish.rawValue == "campfireFinish")
    }

    @Test func displayNames() {
        #expect(CookStage.kitchenPrep.displayName == "Kitchen prep")
        #expect(CookStage.campfireFinish.displayName == "Campfire finish")
    }
}

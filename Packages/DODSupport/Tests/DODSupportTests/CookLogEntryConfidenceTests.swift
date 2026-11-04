import Foundation
import Testing

@testable import DODSupport

@Test func confidenceClampsIntoOneToFive() {
    func make(_ inputConfidence: Int?) -> CookLogEntry {
        CookLogEntry(id: UUID(), recipeID: 1, recipeTitle: "T", cookedAt: .now, confidence: inputConfidence)
    }
    #expect(make(nil).confidence == nil)
    #expect(make(0).confidence == 1)
    #expect(make(9).confidence == 5)
    #expect(make(3).confidence == 3)
}

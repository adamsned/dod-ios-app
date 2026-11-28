import Foundation
import Testing

@testable import DODFeatureRecipeDetail

@Suite("FireCircleBoardView")
struct FireCircleBoardViewTests {
    @Test func clockZero() {
        #expect(FireCircleBoardView.clock(0) == "0:00")
    }

    @Test func clockSecondsAndMinutes() {
        #expect(FireCircleBoardView.clock(65) == "1:05")
    }

    @Test func clockOneHour() {
        #expect(FireCircleBoardView.clock(3600) == "1:00:00")
    }
}

import Foundation
import Testing

@testable import DODFeatureRecipeDetail

struct CampfireTimerReadoutTests {
    @Test func formatsMinutesAndSeconds() {
        #expect(CampfireTimerReadout.format(seconds: 125) == "2:05")
    }
    @Test func formatsHours() {
        #expect(CampfireTimerReadout.format(seconds: 3725) == "1:02:05")
    }
    @Test func negativeClampsToZero() {
        #expect(CampfireTimerReadout.format(seconds: -5) == "0:00")
    }
}

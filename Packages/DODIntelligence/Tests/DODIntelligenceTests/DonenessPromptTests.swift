import Foundation
import Testing

@testable import DODIntelligence

@Suite
struct DonenessPromptTests {
    @Test func emptyPhotoReturnsNil() async {
        let result = await LiveDODIntelligenceService().checkDoneness(photo: Data(), stepText: "x")
        #expect(result == nil)
    }
}

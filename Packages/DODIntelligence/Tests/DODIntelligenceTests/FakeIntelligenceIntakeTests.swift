import DODSupport
import Foundation
import Testing

@testable import DODIntelligence

/// DUT-1032 — the fake returns a canned intake profile.
@Suite("FakeIntelligenceService intake")
struct FakeIntelligenceIntakeTests {

    private let answers = [IntakeAnswer(question: "Any worries?", answer: "Seasoning")]

    @Test func fakeIntakeReturnsCannedProfileWhenAvailable() async {
        let profile = await FakeIntelligenceService().extractIntakeProfile(from: answers)
        #expect(profile?.householdSize == 4)
    }

    @Test func fakeIntakeIsNilWhenUnavailableOrEmpty() async {
        let unavailable = FakeIntelligenceService(isAvailable: false)
        #expect(await unavailable.extractIntakeProfile(from: answers) == nil)
        #expect(await FakeIntelligenceService().extractIntakeProfile(from: []) == nil)
    }
}

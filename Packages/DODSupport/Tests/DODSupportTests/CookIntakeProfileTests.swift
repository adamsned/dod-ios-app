import Foundation
import Testing

@testable import DODSupport

@Suite("CookIntakeProfileTests")
struct CookIntakeProfileTests {

    @Test func intakeAnswerCodableRoundTrips() throws {
        let original = IntakeAnswer(question: "Any worries?", answer: "Seasoning")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(IntakeAnswer.self, from: data)
        #expect(decoded == original)
    }

    @Test func householdSizeIsClamped() {
        let low = CookIntakeProfile(fearLevel: .nervous, occasion: .other, householdSize: 0, biggestWorry: "")
        let high = CookIntakeProfile(fearLevel: .nervous, occasion: .other, householdSize: 99, biggestWorry: "")
        #expect(low.householdSize == 1)
        #expect(high.householdSize == 12)
    }

    @Test func codableRoundTrips() throws {
        let original = CookIntakeProfile(
            fearLevel: .confident,
            occasion: .campout,
            householdSize: 4,
            biggestWorry: "  heat  "
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CookIntakeProfile.self, from: data)
        #expect(decoded == original)
        #expect(decoded.biggestWorry == "heat")
    }

    @Test func normalizedMapsLooseStrings() {
        let profile = CookIntakeProfile.normalized(
            fear: "Nervous",
            occasion: "a campout",
            household: 4,
            worry: " seasoning "
        )
        #expect(profile.fearLevel == .nervous)
        #expect(profile.occasion == .campout)
        #expect(profile.householdSize == 4)
        #expect(profile.biggestWorry == "seasoning")
    }

    @Test func normalizedUnknownsFallBack() {
        let profile = CookIntakeProfile.normalized(fear: "??", occasion: "zzz", household: 2, worry: "")
        #expect(profile.fearLevel == .cautious)
        #expect(profile.occasion == .other)
    }
}

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
}

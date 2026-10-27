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
}

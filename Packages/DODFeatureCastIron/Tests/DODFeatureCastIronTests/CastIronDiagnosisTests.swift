import Foundation
import Testing

@testable import DODFeatureCastIron

@Suite("CastIronDiagnosis + Condition")
struct CastIronDiagnosisTests {

    @Test func everyConditionHasADisplayName() {
        for condition in CastIronCondition.allCases {
            #expect(!condition.displayName.isEmpty)
        }
    }

    @Test func crackedAndNotCastIronAreNotRecoverable() {
        #expect(CastIronCondition.cracked.isRecoverable == false)
        #expect(CastIronCondition.notCastIron.isRecoverable == false)
        #expect(CastIronCondition.lightRust.isRecoverable == true)
        #expect(CastIronCondition.wellSeasoned.isRecoverable == true)
    }

    @Test func diagnosisRoundTripsThroughCodable() throws {
        let original = CastIronDiagnosis(
            condition: .heavyRust,
            confidence: 0.82,
            summary: "Lots of rust.",
            steps: [CareStep(id: 1, title: "Strip", detail: "Steel wool.")],
            safetyNote: nil,
            source: .onDeviceVision
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CastIronDiagnosis.self, from: data)
        #expect(decoded == original)
    }
}

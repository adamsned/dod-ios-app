import Foundation
import Testing

@testable import DODFeatureCastIron

@Suite("CastIronCareService tiering + fallback")
struct CastIronCareServiceTests {

    private static let sampleImage = CastIronImage(data: Data([0x01, 0x02, 0x03]))

    /// A canned diagnoser: returns a fixed diagnosis or throws a fixed error.
    private struct StubDiagnoser: CastIronDiagnoser {
        let result: Result<CastIronDiagnosis, CastIronDiagnoserError>
        func diagnose(_ image: CastIronImage) async throws -> CastIronDiagnosis {
            try result.get()
        }
    }

    @Test func nilDiagnoserReturnsCuratedGeneralCare() async {
        let service = CastIronCareService(diagnoser: nil)
        let out = await service.diagnose(Self.sampleImage)
        #expect(out == CuratedCastIronCare.generalCare)
    }

    @Test func successfulDiagnosisIsReturnedAsIs() async {
        let diagnosis = CuratedCastIronCare.guide(for: .lightRust)
        let service = CastIronCareService(diagnoser: StubDiagnoser(result: .success(diagnosis)))
        let out = await service.diagnose(Self.sampleImage)
        #expect(out.condition == .lightRust)
    }

    @Test func throwingDiagnoserDegradesToCuratedCare() async {
        let service = CastIronCareService(
            diagnoser: StubDiagnoser(result: .failure(.modelUnavailable))
        )
        let out = await service.diagnose(Self.sampleImage)
        #expect(out == CuratedCastIronCare.generalCare)
    }

    @Test func lowConfidenceNotCastIronDegradesToCuratedCare() async {
        let weak = CastIronDiagnosis(
            condition: .notCastIron,
            confidence: 0.1,
            summary: "Unsure.",
            steps: [CareStep(id: 1, title: "x", detail: "y")],
            source: .onDeviceVision
        )
        let service = CastIronCareService(diagnoser: StubDiagnoser(result: .success(weak)))
        let out = await service.diagnose(Self.sampleImage)
        #expect(out == CuratedCastIronCare.generalCare)
    }
}

import Foundation
import Testing

@testable import DODFeatureCastIron

@Suite("CuratedCastIronCare content")
struct CuratedCastIronCareTests {

    @Test func everyConditionHasANonEmptyGuide() {
        for condition in CastIronCondition.allCases {
            let guide = CuratedCastIronCare.guide(for: condition)
            #expect(!guide.summary.isEmpty)
            #expect(!guide.steps.isEmpty)
            #expect(guide.source == .curated)
        }
    }

    @Test func careStepsAreNumberedFromOne() {
        for condition in CastIronCondition.allCases {
            let ids = CuratedCastIronCare.guide(for: condition).steps.map(\.id)
            #expect(ids == Array(1...ids.count))
        }
    }

    @Test func crackedGuideCarriesASafetyNote() {
        let cracked = CuratedCastIronCare.guide(for: .cracked)
        #expect(cracked.condition == .cracked)
        #expect(cracked.safetyNote?.isEmpty == false)
    }

    @Test func notCastIronMapsToGeneralCareFallback() {
        #expect(CuratedCastIronCare.guide(for: .notCastIron) == CuratedCastIronCare.generalCare)
    }
}

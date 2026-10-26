import DODSupport
import Testing

@testable import DODIntelligence

@Suite("LiveDODIntelligenceService aisle mapping")
struct AisleClassificationMappingTests {
    @Test func mapsKnownCasesCaseInsensitively() {
        #expect(LiveDODIntelligenceService.aisle(fromRaw: " Pantry ") == .pantry)
        #expect(LiveDODIntelligenceService.aisle(fromRaw: "spices") == .spices)
    }
    @Test func unknownRawIsNil() {
        #expect(LiveDODIntelligenceService.aisle(fromRaw: "bakery") == nil)
    }
}

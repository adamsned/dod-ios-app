import Foundation
import Testing

@testable import DODSupport

@Suite("GatheringMemory (DUT-978)")
struct GatheringMemoryTests {

    @Test func namesAreTrimmedAndBlanksDropped() {
        let record = GatheringRecord(
            id: UUID(),
            day: Date(timeIntervalSince1970: 0),
            headcount: 4,
            guestNames: [" Sam ", ""]
        )
        #expect(record.guestNames == ["Sam"])
    }

    @Test func negativeHeadcountClampsToZero() {
        let record = GatheringRecord(id: UUID(), day: Date(timeIntervalSince1970: 0), headcount: -3)
        #expect(record.headcount == 0)
    }
}

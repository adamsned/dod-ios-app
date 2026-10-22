import Foundation
import Testing

@testable import DODSupport

@Suite("PanCare (DUT-971)")
struct PanCareTests {
    @Test func stepOrder() {
        #expect(PanCareStep.allCases.map(\.rawValue) == ["wipe", "oil", "done"])
    }
}

import Testing

@testable import DODIntelligence

@Suite("IntelligenceTier")
struct IntelligenceTierTests {
    @Test func defaultTierIsOnDevice() {
        #expect(IntelligenceTier.default == .onDevice)
        #expect(IntelligenceTier.default.isOnDevice)
    }

    @Test func privateCloudComputeIsNotOnDevice() {
        #expect(!IntelligenceTier.privateCloudCompute.isOnDevice)
    }
}

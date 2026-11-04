import Foundation
import Testing

@testable import DODSupport

@Suite("CookerIntakeStore (DUT-982)")
struct CookerIntakeStoreTests {
    private func makeDefaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: "CookerIntakeStoreTests-\(UUID().uuidString)"))
    }

    @Test("loadReturnsNilWhenNothingSaved")
    func loadReturnsNilWhenNothingSaved() throws {
        let defaults = try makeDefaults()
        #expect(CookerIntakeStore.load(from: defaults) == nil)
    }

    @Test("saveThenLoadRoundTrips")
    func saveThenLoadRoundTrips() throws {
        let defaults = try makeDefaults()
        let intake = CookerIntake(hasDutchOven: true, ovenSizeInches: 12, setup: .both, experience: .some)
        CookerIntakeStore.save(intake, to: defaults)
        #expect(CookerIntakeStore.load(from: defaults) == intake)
    }

    @Test("corruptDataLoadsNil")
    func corruptDataLoadsNil() throws {
        let defaults = try makeDefaults()
        defaults.set(Data([0x00]), forKey: CookerIntakeStore.defaultsKey)
        #expect(CookerIntakeStore.load(from: defaults) == nil)
    }
}

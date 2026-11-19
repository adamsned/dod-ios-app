import Foundation
import Testing

@testable import DODSupport

@Suite("HeatCoachConditions") struct HeatCoachConditionsTests {
    private let when = Date(timeIntervalSince1970: 1_000_000)

    private func classify(temp: Double = 65, wind: Double = 0, meters: Double = 0) -> HeatCoachConditions {
        HeatCoachConditions.classify(temperatureF: temp, windMPH: wind, altitudeMeters: meters, fetchedAt: when)
    }

    @Test func hotTemperature_isHot() {
        #expect(classify(temp: 95).ambient == .hot)
    }

    @Test func coldTemperature_isCold() {
        #expect(classify(temp: 30).ambient == .cold)
    }

    @Test func mildTemperature_isMild() {
        #expect(classify(temp: 65).ambient == .mild)
    }

    @Test func lightWind_isNotWindy() {
        #expect(classify(wind: 5).windy == false)
    }

    @Test func thresholdWind_isWindy() {
        #expect(classify(wind: 12).windy == true)
    }

    @Test func altitude1524Meters_is5000Feet() {
        #expect(classify(meters: 1524).elevationFeet == 5000)
    }

    @Test func negativeAltitude_clampsToZero() {
        #expect(classify(meters: -20).elevationFeet == 0)
    }

    @Test func extremeAltitude_capsAt15000() {
        #expect(classify(meters: 9000).elevationFeet == 15000)
    }

    @Test func codableRoundTrip_isEqual() throws {
        let original = HeatCoachConditions(elevationFeet: 5000, ambient: .cold, windy: true, fetchedAt: when)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HeatCoachConditions.self, from: data)
        #expect(decoded == original)
    }
}

import Foundation

/// DUT-998 — conditions for the Heat Coach, either typed in by hand or fetched from sensors/weather.
public struct HeatCoachConditions: Equatable, Sendable {
    public let elevationFeet: Int
    public let ambient: AmbientCondition
    public let windy: Bool
    public let fetchedAt: Date

    public init(elevationFeet: Int, ambient: AmbientCondition, windy: Bool, fetchedAt: Date) {
        self.elevationFeet = elevationFeet
        self.ambient = ambient
        self.windy = windy
        self.fetchedAt = fetchedAt
    }

    /// At or above this wind speed (mph) the cook counts as "windy". Gusts count too, so pass max(sustained, gust).
    public static let windyThresholdMPH: Double = 11
    public static let hotAtOrAboveF: Double = 88
    public static let coldAtOrBelowF: Double = 40

    public static func classify(
        temperatureF: Double,
        windMPH: Double,
        altitudeMeters: Double,
        fetchedAt: Date
    ) -> HeatCoachConditions {
        let ambient: AmbientCondition =
            temperatureF >= hotAtOrAboveF ? .hot : (temperatureF <= coldAtOrBelowF ? .cold : .mild)
        let feet = Int(exactly: (max(0, altitudeMeters) * 3.28084).rounded()) ?? 0
        // Round to the nearest 500 ft so it matches the Elevation stepper (step 500, max 15000).
        let stepped = min(15000, Int(exactly: (Double(feet) / 500.0).rounded()) ?? 0 * 500)
        return HeatCoachConditions(
            elevationFeet: stepped,
            ambient: ambient,
            windy: windMPH >= windyThresholdMPH,
            fetchedAt: fetchedAt
        )
    }
}

extension HeatCoachConditions: Codable {
    private enum AmbientCode: String, Codable {
        case hot, mild, cold
    }

    private enum CodingKeys: String, CodingKey {
        case elevationFeet, ambient, windy, fetchedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let code = try container.decode(AmbientCode.self, forKey: .ambient)
        let ambient: AmbientCondition
        switch code {
        case .hot: ambient = .hot
        case .mild: ambient = .mild
        case .cold: ambient = .cold
        }
        self.init(
            elevationFeet: try container.decode(Int.self, forKey: .elevationFeet),
            ambient: ambient,
            windy: try container.decode(Bool.self, forKey: .windy),
            fetchedAt: try container.decode(Date.self, forKey: .fetchedAt)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let code: AmbientCode
        switch ambient {
        case .hot: code = .hot
        case .mild: code = .mild
        case .cold: code = .cold
        }
        try container.encode(elevationFeet, forKey: .elevationFeet)
        try container.encode(code, forKey: .ambient)
        try container.encode(windy, forKey: .windy)
        try container.encode(fetchedAt, forKey: .fetchedAt)
    }
}

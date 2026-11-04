import Foundation

/// DUT-989 — what the Control Center / Lock Screen "Tonight's Rung" control shows.
public struct TonightsRungSnapshot: Codable, Sendable, Equatable {
    public static let currentSchemaVersion = 1

    public enum Kind: String, Codable, Sendable { case cook, resume }

    public let schemaVersion: Int
    public let writtenAt: Date
    public let kind: Kind
    public let recipeID: Int
    public let title: String
    /// 1-based step; only meaningful for `.resume`.
    public let stepNumber: Int?

    public init(
        schemaVersion: Int = TonightsRungSnapshot.currentSchemaVersion,
        writtenAt: Date,
        kind: Kind,
        recipeID: Int,
        title: String,
        stepNumber: Int? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.writtenAt = writtenAt
        self.kind = kind
        self.recipeID = recipeID
        self.title = title
        self.stepNumber = stepNumber
    }

    /// "Cook: Chili" or "Continue: Step 3 of Chili".
    public var label: String {
        switch kind {
        case .cook: "Cook: \(title)"
        case .resume: "Continue: Step \(stepNumber ?? 1) of \(title)"
        }
    }

    /// Routes straight into Cook Mode for this recipe.
    public var deepLinkIntent: DeepLinkIntent { .startCookMode(recipeID: recipeID) }
}

public enum TonightsRungSnapshotConfig {
    public static let userDefaultsKey = "dod.widget.tonightsRung.v1"
}

extension WidgetSnapshotStore {
    @discardableResult
    public func writeTonightsRung(_ snapshot: TonightsRungSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        defaults.set(data, forKey: TonightsRungSnapshotConfig.userDefaultsKey)
        return data
    }

    /// nil when nothing was written or the schema version mismatches.
    public func readTonightsRung() -> TonightsRungSnapshot? {
        guard let data = defaults.data(forKey: TonightsRungSnapshotConfig.userDefaultsKey) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let snapshot = try? decoder.decode(TonightsRungSnapshot.self, from: data),
            snapshot.schemaVersion == TonightsRungSnapshot.currentSchemaVersion
        else { return nil }
        return snapshot
    }
}

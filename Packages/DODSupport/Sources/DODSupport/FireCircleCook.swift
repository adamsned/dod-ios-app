import Foundation

/// DUT-1001 — one device's active cook as broadcast to the Fire Circle.
public struct FireCircleCook: Codable, Sendable, Equatable, Identifiable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let peerID: String  // stable per-device id (UUID string)
    public let cookName: String  // chef display name
    public let recipeTitle: String
    public let stepText: String
    public let remainingSeconds: Int
    public let endDate: Date?  // nil while paused
    public let isPaused: Bool
    public let isCompleted: Bool
    public let sentAt: Date
    public var id: String { peerID }

    public init(
        schemaVersion: Int = FireCircleCook.currentSchemaVersion,
        peerID: String,
        cookName: String,
        recipeTitle: String,
        stepText: String,
        remainingSeconds: Int,
        endDate: Date?,
        isPaused: Bool,
        isCompleted: Bool,
        sentAt: Date
    ) {
        self.schemaVersion = schemaVersion
        self.peerID = peerID
        self.cookName = cookName
        self.recipeTitle = recipeTitle
        self.stepText = stepText
        self.remainingSeconds = remainingSeconds
        self.endDate = endDate
        self.isPaused = isPaused
        self.isCompleted = isCompleted
        self.sentAt = sentAt
    }
}

extension FireCircleCook {
    /// JSON with millisecond-epoch dates, as exchanged between peers.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return try encoder.encode(self)
    }

    public static func decode(_ data: Data) throws -> FireCircleCook {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return try decoder.decode(FireCircleCook.self, from: data)
    }
}

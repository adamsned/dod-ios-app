import Foundation

/// DUT-968 — a "Pass it down" hand-off from a mentor to a family member.
/// Primitives only so it stays decoupled from Domain/Persistence/UIKit.
public struct LegacyHandoff: Codable, Sendable, Equatable {
    /// Wire-format version, for forward compatibility.
    public static let currentVersion = 1

    public let version: Int
    public let recipeID: Int
    public let recipeTitle: String
    public let recipeURL: URL
    /// The mentor's name for the sign-off line (may be empty).
    public let fromName: String
    /// A short personal message to the learner.
    public let message: String
    /// The mentor's own cook-journal notes, newest first, blanks removed.
    public let notes: [String]
    /// Coal/heat tips the mentor wants to pass on, blanks removed.
    public let coalTips: [String]
    /// Opaque photo ids (e.g. CookLogEntry.photoLocalID). Bytes are not carried here.
    public let photoLocalIDs: [String]

    public init(
        recipeID: Int,
        recipeTitle: String,
        recipeURL: URL,
        fromName: String = "",
        message: String = "",
        notes: [String] = [],
        coalTips: [String] = [],
        photoLocalIDs: [String] = []
    ) {
        func clean(_ xs: [String]) -> [String] {
            xs.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        }
        self.version = Self.currentVersion
        self.recipeID = recipeID
        self.recipeTitle = recipeTitle
        self.recipeURL = recipeURL
        self.fromName = fromName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.message = message.trimmingCharacters(in: .whitespacesAndNewlines)
        self.notes = clean(notes)
        self.coalTips = clean(coalTips)
        self.photoLocalIDs = clean(photoLocalIDs)
    }
}

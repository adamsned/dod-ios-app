import Foundation

/// A WordPress category. Sourced from /wp-json/wp/v2/categories.
/// Spec trace: spec.md AC-2.1, AC-2.2.
public struct Category: Sendable, Hashable, Identifiable, Codable {
    public let id: Int
    public let name: String
    public let slug: String
    public let count: Int
    /// WP category `description` (plain text). Empty when the editor set none.
    public let description: String

    public init(id: Int, name: String, slug: String, count: Int, description: String = "") {
        self.id = id
        self.name = name
        self.slug = slug
        self.count = count
        self.description = description
    }

    private enum CodingKeys: String, CodingKey { case id, name, slug, count, description }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        slug = try container.decode(String.self, forKey: .slug)
        count = try container.decode(Int.self, forKey: .count)
        // Older cached payloads have no `description`; decode leniently.
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
    }
}

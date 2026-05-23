import Foundation

/// A WordPress category. Sourced from /wp-json/wp/v2/categories.
/// Spec trace: spec.md AC-2.1, AC-2.2.
public struct Category: Sendable, Hashable, Identifiable, Codable {
    public let id: Int
    public let name: String
    public let slug: String
    public let count: Int

    public init(id: Int, name: String, slug: String, count: Int) {
        self.id = id
        self.name = name
        self.slug = slug
        self.count = count
    }
}

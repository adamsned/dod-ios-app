import Foundation

/// One piece of equipment / tool a recipe calls for, sourced from the
/// WP Recipe Maker recipe-card `equipment` array.
///
/// WPRM emits each entry with a display `name` and, optionally, an
/// affiliate `link` and a thumbnail `image_url`. Only `name` is
/// guaranteed; the URLs are absent on most cards.
///
/// Spec trace: spec.md AC-51.1.
public struct Equipment: Sendable, Equatable, Hashable, Identifiable, Codable {
    public let id: UUID
    public let name: String
    public let imageURL: URL?
    public let link: URL?

    public init(id: UUID = UUID(), name: String, imageURL: URL? = nil, link: URL? = nil) {
        self.id = id
        self.name = name
        self.imageURL = imageURL
        self.link = link
    }
}

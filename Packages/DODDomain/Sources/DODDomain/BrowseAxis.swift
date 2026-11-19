import Foundation

/// One tappable value inside a browse axis (e.g. "Dinner"). Carries WP tag ids,
/// never free text, so results are deterministic and deep-linkable.
public struct BrowseAxisValue: Sendable, Hashable, Identifiable, Codable {
    /// Stable id used in deep links, e.g. "dinner".
    public let slug: String
    public let title: String
    public let tagIDs: [Int]

    public var id: String { slug }

    public init(slug: String, title: String, tagIDs: [Int]) {
        self.slug = slug
        self.title = title
        self.tagIDs = tagIDs
    }
}

public struct BrowseAxis: Sendable, Hashable, Identifiable, Codable {
    /// "course", "occasion", "protein", "size", "difficulty"
    public let slug: String
    public let title: String
    public let values: [BrowseAxisValue]

    public var id: String { slug }

    public init(slug: String, title: String, values: [BrowseAxisValue]) {
        self.slug = slug
        self.title = title
        self.values = values
    }
}

public struct BrowseAxesConfig: Sendable, Equatable, Codable {
    public let axes: [BrowseAxis]

    public init(axes: [BrowseAxis]) {
        self.axes = axes
    }

    /// Decodes remote-config JSON. Drops axes with no values and values with no tag ids.
    public static func decode(from data: Data) throws -> BrowseAxesConfig {
        let raw = try JSONDecoder().decode(BrowseAxesConfig.self, from: data)
        let cleaned = raw.axes.compactMap { axis -> BrowseAxis? in
            let values = axis.values.filter { !$0.tagIDs.isEmpty }
            return values.isEmpty ? nil : BrowseAxis(slug: axis.slug, title: axis.title, values: values)
        }
        return BrowseAxesConfig(axes: cleaned)
    }
}

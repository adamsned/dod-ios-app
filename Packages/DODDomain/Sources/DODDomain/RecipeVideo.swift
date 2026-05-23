import Foundation

/// Optional inline video from JSON-LD `video.VideoObject`.
/// Spec trace: spec.md AC-4.4, AC-4.5.
public struct RecipeVideo: Sendable, Hashable, Codable {
    public let url: URL
    public let thumbnailURL: URL?
    public let duration: Duration?

    public init(url: URL, thumbnailURL: URL? = nil, duration: Duration? = nil) {
        self.url = url
        self.thumbnailURL = thumbnailURL
        self.duration = duration
    }
}

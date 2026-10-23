import DODDomain
import DODSupport
import Foundation

extension WPRestClient {
    /// Announcement posts, newest first. `categoryID` is the WP "announcements" category id.
    public func announcements(categoryID: Int, perPage: Int = 20) async throws -> [Announcement] {
        let items = [
            URLQueryItem(name: "categories", value: String(categoryID)),
            URLQueryItem(name: "per_page", value: String(perPage)),
            URLQueryItem(name: "orderby", value: "date"),
            URLQueryItem(name: "order", value: "desc"),
            URLQueryItem(name: "_embed", value: "wp:featuredmedia"),
        ]
        let lossy: LossyArray<AnnouncementDTO> = try await get(path: "posts", queryItems: items)
        return lossy.elements.map { $0.toAnnouncement() }
    }
}

private struct AnnouncementDTO: Decodable {
    struct Rendered: Decodable { let rendered: String }
    let id: Int
    let title: Rendered
    let content: Rendered
    let dateGMT: String?
    enum CodingKeys: String, CodingKey {
        case id, title, content
        case dateGMT = "date_gmt"
    }

    func toAnnouncement() -> Announcement {
        Announcement(
            id: id,
            title: title.rendered,
            bodyMarkdown: content.rendered,
            publishedAt: WPDTO.parseWPDate(dateGMT)
        )
    }
}

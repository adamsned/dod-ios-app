import DODDomain
import Foundation

/// DUT-977 — text + QR payload for the at-the-table recipe tent card.
struct TentCardContent: Equatable {
    let dishName: String
    let byline: String
    /// What the QR encodes: the in-app deep link when the id is valid, else the web URL.
    let qrPayload: String

    init(recipe: Recipe, hostName: String?) {
        dishName = recipe.title
        let host = hostName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        byline =
            host.isEmpty
            ? "Made with Dutch Oven Daddy"
            : "Made by \(host) with Dutch Oven Daddy"
        // id <= 0 is a placeholder; `dod://recipe/0` is a dead link, so use the web URL.
        qrPayload =
            recipe.id > 0
            ? "dod://recipe/\(recipe.id)"
            : recipe.canonicalURL.absoluteString
    }
}

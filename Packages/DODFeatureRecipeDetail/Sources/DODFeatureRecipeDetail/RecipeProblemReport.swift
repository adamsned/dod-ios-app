import Foundation

/// DUT-178 — the problem type a cook picks in the Report a Problem sheet.
enum RecipeProblemType: String, CaseIterable, Sendable, Identifiable {
    case ingredient, step, photo, other
    var id: String { rawValue }
    var title: String {
        switch self {
        case .ingredient: "Wrong ingredient/quantity"
        case .step: "Missing or broken step"
        case .photo: "Photo issue"
        case .other: "Other"
        }
    }
}

/// A private, structured correction for one recipe, delivered by email (DUT-176 transport).
struct RecipeProblemReport: Sendable, Equatable {
    static let recipient = "ned@dutchovendaddy.com"
    var recipeID: Int
    var recipeTitle: String
    var problemType: RecipeProblemType
    var note: String

    var subject: String { "[DOD Recipe Problem] \(problemType.title): \(recipeTitle)" }

    var body: String {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        var out = "Recipe: \(recipeTitle)\nRecipe ID: \(recipeID)\nProblem: \(problemType.title)"
        if !trimmed.isEmpty { out += "\n\n\(trimmed)" }
        return out
    }

    /// Pre-filled mailto: URL to the team.
    var mailtoURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = Self.recipient
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body),
        ]
        return components.url
    }
}

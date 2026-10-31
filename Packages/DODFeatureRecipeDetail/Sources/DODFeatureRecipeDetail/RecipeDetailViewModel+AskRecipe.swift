import Foundation

public struct AskRecipeMessage: Equatable, Sendable, Identifiable {
    public enum Role: Sendable { case user, assistant }
    public let id = UUID()
    public let role: Role
    public let text: String

    public init(role: Role, text: String) {
        self.role = role
        self.text = text
    }
}

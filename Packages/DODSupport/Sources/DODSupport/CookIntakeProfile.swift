import Foundation

/// One question/answer exchange from the conversational onboarding intake (DUT-1032).
public struct IntakeAnswer: Sendable, Equatable, Codable {
    public let question: String
    public let answer: String

    public init(question: String, answer: String) {
        self.question = question
        self.answer = answer
    }
}

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

/// Typed cold-start profile extracted from the intake conversation.
public struct CookIntakeProfile: Sendable, Equatable, Codable {

    public enum FearLevel: String, Sendable, Codable, CaseIterable {
        case nervous, cautious, confident
    }

    public enum Occasion: String, Sendable, Codable, CaseIterable {
        case weeknightDinner, weekendCook, campout, entertaining, other
    }

    public let fearLevel: FearLevel
    public let occasion: Occasion
    /// Clamped to 1...12.
    public let householdSize: Int
    /// What the cook said scares them, trimmed; may be empty.
    public let biggestWorry: String

    public init(
        fearLevel: FearLevel,
        occasion: Occasion,
        householdSize: Int,
        biggestWorry: String
    ) {
        self.fearLevel = fearLevel
        self.occasion = occasion
        self.householdSize = min(max(householdSize, 1), 12)
        self.biggestWorry = biggestWorry.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension CookIntakeProfile {

    /// Maps loose model strings onto the typed enums.
    /// Unknown fear -> .cautious, unknown occasion -> .other.
    public static func normalized(
        fear: String,
        occasion: String,
        household: Int,
        worry: String
    ) -> CookIntakeProfile {
        let fearText = fear.lowercased()
        let occasionText = occasion.lowercased()

        let level: FearLevel
        if fearText.contains("nerv") {
            level = .nervous
        } else if fearText.contains("conf") {
            level = .confident
        } else {
            level = .cautious
        }

        let mapped: Occasion
        if occasionText.contains("camp") {
            mapped = .campout
        } else if occasionText.contains("week") && occasionText.contains("night") {
            mapped = .weeknightDinner
        } else if occasionText.contains("tuesday") {
            mapped = .weeknightDinner
        } else if occasionText.contains("weekend") {
            mapped = .weekendCook
        } else if occasionText.contains("entertain") {
            mapped = .entertaining
        } else if occasionText.contains("party") {
            mapped = .entertaining
        } else if occasionText.contains("guest") {
            mapped = .entertaining
        } else {
            mapped = .other
        }

        return CookIntakeProfile(
            fearLevel: level,
            occasion: mapped,
            householdSize: household,
            biggestWorry: worry
        )
    }
}

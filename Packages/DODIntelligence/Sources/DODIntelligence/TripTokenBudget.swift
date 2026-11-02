import DODDomain
import Foundation

public enum TripTokenBudget {
    public static let contextWindowTokens = 4096
    /// Leave room for instructions + the model's reply.
    public static let reservedTokens = 1200
    static let charsPerToken = 4

    public static func estimateTokens(_ text: String) -> Int {
        (text.count + charsPerToken - 1) / charsPerToken
    }

    /// Tokens needed to show the model one slot's candidate list (id + title + diet tags).
    public static func slotPromptTokens(candidates: [Recipe]) -> Int {
        estimateTokens(
            candidates.map { "\($0.id) \($0.title) \($0.suitableForDiet.joined(separator: ","))" }
                .joined(separator: "\n")
        )
    }

    /// True when ONE slot's prompt already overflows, or the running transcript of
    /// `slotCount` picks (about 12 tokens each) would overflow the window. Such a plan
    /// is flagged for PCC escalation rather than attempted on-device.
    public static func needsEscalation(candidates: [Recipe], slotCount: Int) -> Bool {
        let budget = contextWindowTokens - reservedTokens
        let perSlot = slotPromptTokens(candidates: candidates)
        let transcript = max(0, slotCount) * 12
        return perSlot + transcript > budget
    }
}

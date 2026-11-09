import DODSupport
import Foundation

#if os(iOS)
import FoundationModels
#endif

/// Apple-Intelligence next-rung coach (DUT-1030). The model only reranks the top
/// candidates `NextRungScorer` already surfaced, via a tool; it never invents a
/// recipe. An unknown pick ID, any error, thin data or an unavailable model all
/// fall back to ``DeterministicNextRungCoach``.
public struct LiveNextRungCoach: NextRungCoaching {
    private let fallback = DeterministicNextRungCoach()

    public init() {}

    public func recommend(
        candidates: [NextRungCandidate],
        signals: NextRungSignals,
        lastCookedDifficulty: Int?,
        easier: Bool
    ) async -> [NextRungRecommendation] {
        let base = await fallback.recommend(
            candidates: candidates,
            signals: signals,
            lastCookedDifficulty: lastCookedDifficulty,
            easier: easier
        )
        // Thin data: stay non-AI so it never feels like guessing.
        guard !base.isEmpty, !NextRungScorer.isColdStart(signals) else { return base }
        #if os(iOS)
        if #available(iOS 26, *), let pick = await Self.modelPick(from: Array(base.prefix(5)), signals: signals) {
            if let resolved = Self.resolve(pickID: pick.recipeID, why: pick.why, in: base) {
                return [resolved] + base.filter { $0.candidate.recipeID != resolved.candidate.recipeID }
            }
        }
        #endif
        return base
    }

    /// Pure guard: accept the model's pick only if its ID is a real surfaced candidate.
    static func resolve(
        pickID: Int,
        why: String,
        in ranked: [NextRungRecommendation]
    ) -> NextRungRecommendation? {
        guard let match = ranked.first(where: { $0.candidate.recipeID == pickID }) else { return nil }
        let trimmed = why.trimmingCharacters(in: .whitespacesAndNewlines)
        return NextRungRecommendation(
            candidate: match.candidate,
            why: trimmed.isEmpty ? match.why : trimmed,
            isColdStart: false
        )
    }

    #if os(iOS)
    /// The single place that touches the model. Re-checks availability, runs one
    /// structured turn with the candidates tool, and returns `(recipeID, why)`.
    /// Any error (including a guardrail rejection) is swallowed to `nil`.
    @available(iOS 26, *)
    static func modelPick(
        from top: [NextRungRecommendation],
        signals: NextRungSignals
    ) async -> (recipeID: Int, why: String)? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }
        let lines = top.map { "\($0.candidate.recipeID) | \($0.candidate.title) | \($0.candidate.difficulty)" }
        let session = LanguageModelSession(
            tools: [NextRungCandidatesTool(lines: lines.joined(separator: "\n"))],
            instructions: nextRungInstructions
        )
        do {
            let reply = try await session.respond(
                to: prompt(signals: signals),
                generating: GenerableNextRungPick.self
            )
            return (reply.content.recipeID, reply.content.why)
        } catch {
            return nil
        }
    }

    @available(iOS 26, *)
    private static func prompt(signals: NextRungSignals) -> String {
        var lines = ["Pick the best next recipe for this home cook."]
        if let days = signals.daysSinceLastCook { lines.append("Days since last cook: \(days)") }
        if let rating = signals.lastRating { lines.append("Last cook rating (1-5): \(rating)") }
        lines.append("Weekly cooking streak: \(signals.weeklyStreak)")
        if let next = signals.cooksToNextRank { lines.append("Cooks to next rank: \(next)") }
        return lines.joined(separator: "\n")
    }

    @available(iOS 26, *)
    private static let nextRungInstructions = """
        You are a friendly cast-iron and Dutch-oven cooking coach. Call the \
        candidate tool, then choose exactly one recipe from its list. You must \
        return a recipeID that appears in the tool output; never invent a recipe. \
        Explain the pick in one short, encouraging sentence.
        """
    #endif
}

#if os(iOS)
/// The model's structured pick (DUT-1030).
@available(iOS 26, *)
@Generable
struct GenerableNextRungPick {
    @Guide(description: "The recipeID of one candidate returned by the tool")
    var recipeID: Int

    @Guide(description: "One short, encouraging sentence on why this is the right next recipe")
    var why: String
}

/// Hands the model the surfaced candidates as `id | title | difficulty` lines (DUT-1030).
@available(iOS 26, *)
struct NextRungCandidatesTool: Tool {
    let lines: String
    let name = "listNextRungCandidates"
    let description = "Lists the candidate recipes as 'id | title | difficulty' lines."
    @Generable struct Arguments {
        @Guide(description: "Why the list is needed; may be empty") var reason: String
    }
    func call(arguments: Arguments) async throws -> String {
        lines
    }
}
#endif

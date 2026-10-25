import Foundation

#if os(iOS)
import FoundationModels
#endif
#if compiler(>=6.4)
import CoreGraphics
import ImageIO
#endif

extension LiveDODIntelligenceService {
    public func checkDoneness(photo: Data, stepText: String) async -> DonenessCheckResult? {
        let step = stepText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !photo.isEmpty, !step.isEmpty else { return nil }
        #if os(iOS) && compiler(>=6.4)
        if #available(iOS 27, *) { return await Self.generateDoneness(photo: photo, stepText: step) }
        #endif
        return nil
    }

    static let donenessInstructions = """
        You are a calm cast-iron cooking coach. Look at the photo and the recipe step and say whether the \
        food LOOKS done for that step (browning, bubbling, rise, char). Judge only what is visible. \
        NEVER state or imply a temperature, internal doneness, or food safety; for meat that is the \
        thermometer's job. If the photo is unclear, say unsure with low confidence.
        """

    static func donenessPrompt(stepText: String) -> String {
        "Current recipe step: \(String(stepText.prefix(1000)))\nDoes the food in the photo look done for this step?"
    }

    /// Map the model's strings onto the plain result; unknown verdict becomes .unsure.
    static func mapDoneness(verdict: String, confidence: Double, reassurance: String) -> DonenessCheckResult? {
        let text = reassurance.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = verdict.lowercased()
        let mapped: DonenessCheckResult.Verdict =
            lower.contains("notyet") || lower.contains("not yet")
            ? .notYet
            : lower.contains("done") ? .looksDone : .unsure
        return DonenessCheckResult(verdict: mapped, confidence: confidence, reassurance: text)
    }
}

#if os(iOS) && compiler(>=6.4)
@available(iOS 27, *)
@Generable
struct GenerableDoneness {
    @Guide(description: "Exactly one of: looksDone, notYet, unsure") var verdict: String
    @Guide(description: "0 to 1") var confidence: Double
    @Guide(description: "One or two calm sentences about what is visible. No temperatures.")
    var reassurance: String
}

extension LiveDODIntelligenceService {
    @available(iOS 27, *)
    static func generateDoneness(photo: Data, stepText: String) async -> DonenessCheckResult? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }
        guard let cgImage = decodeCGImage(from: photo) else { return nil }
        let session = LanguageModelSession(instructions: donenessInstructions)
        let prompt = donenessPrompt(stepText: stepText)
        do {
            let reply = try await session.respond(generating: GenerableDoneness.self) {
                prompt
                Attachment(cgImage)
            }
            let generated = reply.content
            return mapDoneness(
                verdict: generated.verdict,
                confidence: generated.confidence,
                reassurance: generated.reassurance
            )
        } catch {
            return nil
        }
    }
}
#endif

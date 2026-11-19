import Foundation

#if os(iOS)
import FoundationModels
#endif

// The on-device Hero Moment caption turn (DUT-1008), split out of
// `LiveDODIntelligenceService.swift` like the substitution turn.
extension LiveDODIntelligenceService {

    /// Pure (testable on macOS): the user turn for a moment caption. The note is capped at 1000 chars.
    static func momentCaptionPrompt(for request: MomentCaptionRequest) -> String {
        var lines = ["Dish: \(request.recipeTitle)"]
        if let rating = request.personalRating { lines.append("Cook's own rating: \(rating) of 5") }
        if let note = request.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
            lines.append("Cook's private note: \(String(note.prefix(1000)))")
        }
        lines.append("Write the caption now.")
        return lines.joined(separator: "\n")
    }

    #if os(iOS)
    /// One caption turn. Uses the photo when present (iOS 27+ SDK), else text only.
    /// Any error (guardrail, model, bad image) degrades to the text turn, then to `nil`.
    @available(iOS 26, *)
    static func generateMomentCaption(_ request: MomentCaptionRequest) async -> String? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }
        let prompt = momentCaptionPrompt(for: request)
        #if compiler(>=6.4)
        if let data = request.imageData, #available(iOS 27, *), let cgImage = decodeCGImage(from: data) {
            let session = LanguageModelSession(instructions: momentCaptionInstructions)
            do {
                let reply = try await session.respond {
                    prompt
                    Attachment(cgImage)
                }
                let text = reply.content.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { return text }
            } catch {
                // fall through to the text-only turn
            }
        }
        #endif
        let session = LanguageModelSession(instructions: momentCaptionInstructions)
        do {
            let reply = try await session.respond(to: prompt)
            let text = reply.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        } catch {
            return nil
        }
    }

    @available(iOS 26, *)
    private static let momentCaptionInstructions = """
        You write a short, warm, celebratory caption (one or two sentences, under \
        200 characters, at most one emoji) for a home cook proudly sharing a \
        dish they made. Use only what the photo, note and rating show; never \
        invent ingredients, people or events. No hashtags. Output only the caption.
        """
    #endif
}

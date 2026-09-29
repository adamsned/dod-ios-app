import DODIntelligence
import DODSupport
import Foundation

// US-54 / T-932 (AC-54.2) — the on-device "Summarize" flow for recipe detail
// (US-4) and article detail (US-37), split out of `RecipeDetailViewModel.swift`
// to keep that file under the SwiftLint 400-line `file_length` cap. The stored
// `intelligence` seam + the observed `summary` state live in the main class
// body (they must, for `@Observable` tracking); the state machine + request
// flow live here.
//
// Boundary: this depends only on the DODIntelligence PROTOCOL and plain value
// types. FoundationModels is never imported into DODFeatureRecipeDetail — the
// Live model impl is a leaf package the App injects. This mirrors the Shopping
// List substitution seam (`ShoppingListViewModel+Substitution.swift`, #735).
extension RecipeDetailViewModel {

    /// The summary surface's state machine. Drives the summary sheet: `.idle`
    /// keeps it dismissed; `.loading` shows a spinner; `.loaded` shows the
    /// summary; `.notFound` shows the graceful "no summary available" copy
    /// (unavailable / empty body / model error / guardrail rejection — the
    /// service never throws).
    public enum SummaryState: Equatable, Sendable {
        case idle
        case loading
        case loaded(text: String)
        case notFound
    }

    /// `true` only when an on-device model is usable right now. The Summarize
    /// affordance is shown ONLY when this is `true`, so unsupported devices
    /// (iOS 17-25, incapable hardware, no Apple Intelligence, the simulator)
    /// never see a dead control — the button is ABSENT, not disabled.
    public var isSummaryAvailable: Bool {
        intelligence?.isAvailable ?? false
    }

    /// The already-cached body text handed to the model. Nothing new is
    /// fetched. For an article this is the stored `articleBodyHTML` stripped to
    /// plain text (via ``HTMLSanitizer/plainText(from:)``); for a recipe it is
    /// the narrative blurb prose the detail already parsed (``blurbBlocks``).
    /// Both fall back to the recipe `excerpt` when the richer body is empty.
    public var summaryBodyText: String {
        // Article branch: the load state carries the classified article, whose
        // body is raw HTML — strip it to readable text for the model.
        if case .article(let article) = loadState {
            let stripped = HTMLSanitizer.plainText(from: article.articleBodyHTML ?? "")
            return stripped.isEmpty ? article.excerpt : stripped
        }
        // Recipe branch: prefer the parsed narrative blurb, else the excerpt.
        let blurb = Self.plainText(from: blurbBlocks)
        if !blurb.isEmpty {
            return blurb
        }
        return recipe?.excerpt ?? ""
    }

    /// Flatten the parsed narrative blocks to plain text for the model,
    /// keeping only the text-bearing cases (headings, paragraphs, list items)
    /// in document order and dropping images.
    static func plainText(from blocks: [ArticleBlock]) -> String {
        let lines: [String] = blocks.compactMap { block in
            switch block {
            case .heading(_, let text), .paragraph(let text):
                return String(text.characters)
            case .list(_, let items):
                return items.map { String($0.characters) }.joined(separator: "\n")
            case .image:
                return nil
            }
        }
        return
            lines
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Request a summary of the already-cached body text, driving ``summary``
    /// through `.loading` → `.loaded` / `.notFound`. No-op (leaves state
    /// `.idle`) when no model is available, so a spurious call on an
    /// unsupported device can't open an empty sheet. The underlying service
    /// never throws — a `nil` (or empty) result becomes the graceful
    /// `.notFound` state.
    public func requestSummary() async {
        guard let intelligence, intelligence.isAvailable else { return }
        let body = summaryBodyText
        summary = .loading
        let result = await intelligence.summarize(body)
        // Guard against a stale completion: if the user dismissed the sheet
        // while this awaited, don't clobber the newer `.idle` state.
        guard case .loading = summary else { return }
        if let result, !result.isEmpty {
            summary = .loaded(text: result)
        } else {
            summary = .notFound
        }
    }

    /// Dismiss the summary sheet (return to `.idle`).
    public func dismissSummary() {
        summary = .idle
    }
}

import Foundation

public enum CommentDigestPipeline {
    /// Cap on comments considered (most recent / most substantive).
    public static let maxComments = 60
    /// ~1,500 tokens of comment text per model call, leaving room for instructions + output.
    public static let maxChunkCharacters = 6000

    /// Trim, drop bodies under 25 chars, keep the longest `maxComments`
    /// (stable: ties keep input order = most recent first).
    public static func select(_ bodies: [String]) -> [String] {
        let cleaned =
            bodies
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 25 }
        guard cleaned.count > maxComments else { return cleaned }
        let keep = Set(
            cleaned
                .enumerated()
                .sorted { ($0.element.count, -$0.offset) > ($1.element.count, -$1.offset) }
                .prefix(maxComments)
                .map(\.offset)
        )
        return cleaned.enumerated().filter { keep.contains($0.offset) }.map(\.element)
    }

    /// Greedy pack bodies into chunks <= maxChunkCharacters (each body truncated to the cap).
    public static func chunk(_ bodies: [String]) -> [[String]] {
        var chunks: [[String]] = []
        var current: [String] = []
        var size = 0
        for raw in bodies {
            let body = String(raw.prefix(maxChunkCharacters))
            if size + body.count > maxChunkCharacters, !current.isEmpty {
                chunks.append(current)
                current = []
                size = 0
            }
            current.append(body)
            size += body.count
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
    }

    /// Map each chunk to a partial digest, then reduce: if more than one partial,
    /// feed their lines back through `generate` once as a single chunk.
    /// Result is filtered through `grounded(in:)` against the original bodies.
    public static func run(
        bodies: [String],
        generate: @Sendable ([String]) async -> CommentDigest?
    ) async -> CommentDigest? {
        let selected = select(bodies)
        guard !selected.isEmpty else { return nil }
        var partials: [CommentDigest] = []
        for chunk in chunk(selected) {
            if let digest = await generate(chunk) { partials.append(digest) }
        }
        guard !partials.isEmpty else { return nil }
        var merged = partials[0]
        if partials.count > 1 {
            let lines = partials.flatMap { [$0.summary] + $0.tips + $0.gotchas }.filter { !$0.isEmpty }
            merged = await generate(lines) ?? partials[0]
        }
        let result = merged.grounded(in: selected)
        return result.isEmpty ? nil : result
    }
}

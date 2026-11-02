import Foundation

/// DUT-1023 — the community-wisdom digest distilled from approved comments.
public struct CommentDigest: Sendable, Equatable, Codable {
    public let summary: String
    public let tips: [String]
    public let gotchas: [String]

    public init(summary: String, tips: [String], gotchas: [String]) {
        self.summary = summary
        self.tips = tips
        self.gotchas = gotchas
    }

    public var isEmpty: Bool { summary.isEmpty && tips.isEmpty && gotchas.isEmpty }
}

extension CommentDigest {

    /// Keep only lines whose significant words (lowercased, >= 4 letters) are at
    /// least `minOverlap` present in `sources`. Anything the model invented is dropped.
    public func grounded(in sources: [String], minOverlap: Double = 0.6) -> CommentDigest {
        let haystack = Set(Self.words(sources.joined(separator: " ")))
        func keep(_ line: String) -> Bool {
            let ws = Self.words(line)
            guard !ws.isEmpty else { return false }
            let hits = ws.filter { haystack.contains($0) }.count
            return Double(hits) / Double(ws.count) >= minOverlap
        }
        return CommentDigest(
            summary: keep(summary) ? summary : "",
            tips: tips.filter(keep),
            gotchas: gotchas.filter(keep)
        )
    }

    static func words(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { $0.count >= 4 }
    }

    /// Deterministic fixture for `FakeIntelligenceService` and previews.
    public static let canned = CommentDigest(
        summary: "Readers love it and say to watch the heat.",
        tips: ["Brine it an extra hour."],
        gotchas: ["Coals run hot in this one."]
    )
}

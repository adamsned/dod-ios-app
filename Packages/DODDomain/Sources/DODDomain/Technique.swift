import Foundation

/// DUT-973 — a durable, transferable cooking technique a recipe teaches.
public enum Technique: String, CaseIterable, Sendable, Codable, Hashable {
    case sear, braise, bake, roast, fry, simmer, saute, grill

    /// Past-tense verb for copy: "you've now seared, braised ...".
    public var pastTense: String {
        switch self {
        case .sear: "seared"
        case .braise: "braised"
        case .bake: "baked"
        case .roast: "roasted"
        case .fry: "fried"
        case .simmer: "simmered"
        case .saute: "sautéed"
        case .grill: "grilled"
        }
    }

    /// Lowercase substrings that signal this technique.
    var keywords: [String] {
        switch self {
        case .sear: ["sear"]
        case .braise: ["braise", "braising"]
        case .bake: ["bake", "baked", "baking"]
        case .roast: ["roast"]
        case .fry: ["fry", "fried", "frying"]
        case .simmer: ["simmer"]
        case .saute: ["saute", "sauté"]
        case .grill: ["grill"]
        }
    }

    /// Every technique whose keyword appears in `text` (case-insensitive), in `allCases` order.
    public static func detect(in text: String) -> [Technique] {
        let lower = text.lowercased()
        return allCases.filter { technique in technique.keywords.contains { lower.contains($0) } }
    }
}

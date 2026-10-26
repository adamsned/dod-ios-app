import Foundation

/// DUT-992 — maps on-device image-classifier labels for a cast-iron pan to a coaching verdict.
public enum PanCheck {
    public enum Verdict: String, CaseIterable, Sendable, Equatable {
        case rustOrCarbon  // rust / carbon build-up: needs re-seasoning
        case wellSeasoned  // dark, even, glossy: ready to cook
        case unclear  // classifier not confident

        public var headline: String {
            switch self {
            case .rustOrCarbon: return "This pan needs a re-season"
            case .wellSeasoned: return "Looks seasoned. Good to cook."
            case .unclear: return "Hard to tell from here"
            }
        }
        public var advice: String {
            switch self {
            case .rustOrCarbon:
                return "Scrub off loose rust or flaking carbon, dry it, then rub on a thin coat of oil and bake it."
            case .wellSeasoned: return "A dark, even, slightly glossy surface is what you want. Wipe, oil, done."
            case .unclear: return "Try again in better light, closer to the cooking surface."
            }
        }
    }

    public static let minConfidence: Float = 0.3
    static let rustKeywords = ["rust", "corrosion", "carbon", "soot", "burnt", "burned"]
    static let seasonedKeywords = ["skillet", "frying pan", "wok", "cast iron", "dutch oven", "cauldron"]

    /// `labels` are (identifier, confidence) pairs from an image classifier. Rust/carbon keywords win over pan keywords.
    public static func verdict(fromLabels labels: [(identifier: String, confidence: Float)]) -> Verdict {
        let strong = labels.filter { $0.confidence >= minConfidence }
        func hit(_ keys: [String]) -> Bool {
            strong.contains { label in keys.contains { label.identifier.lowercased().contains($0) } }
        }
        if hit(rustKeywords) { return .rustOrCarbon }
        if hit(seasonedKeywords) { return .wellSeasoned }
        return .unclear
    }
}

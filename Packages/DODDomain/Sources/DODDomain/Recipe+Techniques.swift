import Foundation

extension Recipe {
    /// DUT-973 — techniques this recipe teaches, inferred from its title plus
    /// instruction text. Empty for articles.
    public var techniques: [Technique] {
        guard kind == .recipe else { return [] }
        let text = ([title] + instructions.map(\.text)).joined(separator: " ")
        return Technique.detect(in: text)
    }
}

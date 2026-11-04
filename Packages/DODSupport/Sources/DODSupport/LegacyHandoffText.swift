import Foundation

/// DUT-968 — plain-text rendering of a hand-off, for the share sheet.
public enum LegacyHandoffText {
    public static func render(_ handoff: LegacyHandoff) -> String {
        var lines: [String] = []
        if !handoff.message.isEmpty {
            lines.append(handoff.message)
            lines.append("")
        }
        lines.append("Recipe: \(handoff.recipeTitle)")
        lines.append(handoff.recipeURL.absoluteString)
        if !handoff.notes.isEmpty {
            lines.append("")
            lines.append("My notes:")
            lines.append(contentsOf: handoff.notes.map { "- \($0)" })
        }
        if !handoff.coalTips.isEmpty {
            lines.append("")
            lines.append("Coal tips:")
            lines.append(contentsOf: handoff.coalTips.map { "- \($0)" })
        }
        if !handoff.fromName.isEmpty {
            lines.append("")
            lines.append("— \(handoff.fromName)")
        }
        return lines.joined(separator: "\n")
    }
}

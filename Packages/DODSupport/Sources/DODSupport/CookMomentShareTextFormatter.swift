import Foundation

/// Formats the shareable text for a personal cook-log moment (DUT-1008).
/// Pure: the caption is produced elsewhere (on-device AI, or the user's edit).
/// Private notes are never included unless the caption itself contains them.
public enum CookMomentShareTextFormatter {

    /// - Parameters:
    ///   - caption: AI-drafted or user-edited caption; blank is treated as absent.
    ///   - entry: The cook-log entry being shared.
    ///   - recipeURL: Optional public link to the recipe.
    public static func text(caption: String?, entry: CookLogEntry, recipeURL: URL? = nil) -> String {
        let trimmed = caption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var lines: [String] = []
        lines.append(trimmed.isEmpty ? "I made \(entry.recipeTitle)!" : trimmed)
        if !trimmed.isEmpty { lines.append("— \(entry.recipeTitle)") }
        if let recipeURL { lines.append(recipeURL.absoluteString) }
        return lines.joined(separator: "\n")
    }
}

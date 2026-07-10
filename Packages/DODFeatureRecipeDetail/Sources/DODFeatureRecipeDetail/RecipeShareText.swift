import DODDomain
import Foundation

/// DUT-889 — iOS parity twin of Android's DUT-886 "Share Recipe as Text".
/// Pure string formatting, deliberately free of SwiftUI/`ShareLink` so it's
/// trivially unit-testable. `RecipeDetailView+Toolbar.swift` feeds this the
/// currently-loaded `Recipe` and shares the resulting string alongside the
/// existing URL-only `ShareLink`.
public enum RecipeShareTextFormatter {

    /// Formats `recipe` as a plain-text block: title, then an "Ingredients:"
    /// section, then a "Steps:" section, then the canonical URL — each
    /// separated by a single blank line. Either section is omitted entirely
    /// (no header, no stray blank line) when the corresponding array is
    /// empty. Instructions are sorted by `step` ascending before formatting,
    /// since callers aren't guaranteed to hand them in order.
    public static func format(recipe: Recipe) -> String {
        var sections: [String] = [recipe.title]

        if !recipe.ingredients.isEmpty {
            let lines = recipe.ingredients.map { "- \($0.text)" }
            sections.append((["Ingredients:"] + lines).joined(separator: "\n"))
        }

        if !recipe.instructions.isEmpty {
            let sorted = recipe.instructions.sorted { $0.step < $1.step }
            let lines = sorted.map { "\($0.step). \($0.text)" }
            sections.append((["Steps:"] + lines).joined(separator: "\n"))
        }

        sections.append(recipe.canonicalURL.absoluteString)

        return sections.joined(separator: "\n\n")
    }
}

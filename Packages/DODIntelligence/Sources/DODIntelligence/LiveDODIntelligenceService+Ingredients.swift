import Foundation

// DUT-1977 — on-device fridge-photo ingredient identification, split out of
// `LiveDODIntelligenceService.swift` to keep that file under the SwiftLint
// 400-line cap. The pure parser lives here so it is testable on macOS.
extension LiveDODIntelligenceService {

    /// Comma/semicolon/newline separated names -> lowercased, trimmed,
    /// de-duplicated list (via ``PantryMatcher/normalize(_:)``).
    static func parseIngredientList(_ raw: String) -> [String] {
        PantryMatcher.normalize(
            raw.split(whereSeparator: { ",\n;".contains($0) }).map(String.init)
        )
    }
}

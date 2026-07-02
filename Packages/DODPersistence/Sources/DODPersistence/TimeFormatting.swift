import Foundation

/// DUT-373: format a duration in seconds for a recipe time chip — `<= 0`s → nil
/// (no chip), `1...59`s → `"<1 min"`, then `"N min"` / `"N hr"` / spaced hour
/// form. Extracted from `RecipeStore.swift` (a free function, no actor coupling)
/// so that file stays under the SwiftLint 400-line `file_length` cap after the
/// DUT-373/413 additions pushed it to 403.
func formatTime(seconds: Int) -> String? {
    guard seconds > 0 else { return nil }
    let minutes = seconds / 60
    if minutes == 0 { return "<1 min" }
    if minutes < 60 { return "\(minutes) min" }
    let hours = minutes / 60
    let remainder = minutes % 60
    if remainder == 0 { return "\(hours) hr" }
    return "\(hours) hr \(remainder) min"
}

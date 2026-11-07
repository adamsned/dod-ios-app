import Foundation

/// DUT-2446 — the assistant must never mention sanding cast iron. Prompts alone
/// are not a guarantee with an on-device model, so every answer path also runs
/// its reply through this guard (same idea as `DonenessCheckResult.containsSafetyClaim`).
public enum SandingGuard {
    /// Whole-word match, so "sandwich", "thousand" and "sandbox" do not match.
    private static let pattern =
        "\\b(sand|sanding|sanded|sandpaper|sandpapering|sander|sanders|grit|flap\\s+disc|angle\\s+grinder)\\b"

    /// True when the text mentions sanding or grinding a cooking surface.
    public static func containsSandingMention(_ text: String) -> Bool {
        text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
}

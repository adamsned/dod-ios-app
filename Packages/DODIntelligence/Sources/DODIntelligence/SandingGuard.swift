import Foundation

/// DUT-2446 — the assistant must never mention sanding cast iron. Prompts alone
/// are not a guarantee with an on-device model, so every answer path also runs
/// its reply through this guard (same idea as `DonenessCheckResult.containsSafetyClaim`).
public enum SandingGuard {
    /// Whole-word match, so "sandwich", "thousand" and "sandbox" do not match.
    private static let pattern =
        "\\b(sand|sanding|sanded|sandpaper|sandpapering|sander|sanders|grit|flap\\s+disc|angle\\s+grinder)\\b"

    /// Safe line shown instead of any answer that mentions sanding.
    public static let fallback =
        "Scrub off the rust with steel wool or a chainmail scrubber, rinse, dry it on the stove, "
        + "then re-season with a thin coat of oil."

    /// True when the text mentions sanding or grinding a cooking surface.
    public static func containsSandingMention(_ text: String) -> Bool {
        text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// Returns the answer unchanged, or the fallback line when it mentions sanding.
    public static func sanitize(_ answer: String) -> String {
        containsSandingMention(answer) ? fallback : answer
    }

    /// Optional-friendly form for the answer paths.
    public static func sanitize(_ answer: String?) -> String? {
        answer.map { sanitize($0) }
    }
}

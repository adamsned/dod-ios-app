import DODDesignSystem
import SwiftUI

/// Default profile avatar — a single uppercase letter rendered inside a
/// solid circle, used when the user has not uploaded a photo yet (Phase
/// a) or while a photo is loading. Phase b's photo flow replaces this
/// view with the saved photo when one exists; the Settings section
/// shows this avatar at 60pt diameter, scalable elsewhere.
///
/// **Letter extraction.** The first Unicode scalar that is a letter
/// (per `Character.isLetter`) in the trimmed display name is uppercased.
/// An empty display name, a name made entirely of emoji or punctuation,
/// or a leading non-letter falls back to `"?"` — never crashes on an
/// unexpected input. The "🌟 Spencer" → "S" + "" → "?" behavior is
/// pinned by the test suite.
///
/// **Background color.** `DODColor.accent` (the brand burnt-orange) so
/// the avatar reads as "this is you" rather than an arbitrary system
/// color. Locked decision per CL-136 — initial-letter circle on the
/// accent fill, no per-name color hashing in Phase a (a future polish
/// pass can introduce a deterministic hash → palette mapping if a
/// "stronger identity" cue is wanted).
///
/// Spec trace: US-44 AC-44.5; CL-136.
public struct InitialLetterAvatarView: View {

    public let displayName: String
    public let diameter: CGFloat

    public init(displayName: String, diameter: CGFloat = 60) {
        self.displayName = displayName
        self.diameter = diameter
    }

    public var body: some View {
        Circle()
            .fill(DODColor.accent)
            .frame(width: diameter, height: diameter)
            .overlay(
                Text(Self.initialLetter(from: displayName))
                    .font(.system(size: diameter * 0.45, weight: .semibold))
                    .foregroundStyle(DODColor.labelOnAccent)
            )
            .accessibilityHidden(true)
    }

    /// Returns the single uppercase initial for the given display name,
    /// or `"?"` for any input that contains no letter character.
    /// Exposed `static` so the L1 test suite can pin the extraction
    /// rules (empty, two-word, emoji-prefix, all-emoji) without spinning
    /// up a view host.
    public static func initialLetter(from displayName: String) -> String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "?" }
        // First *letter* — skips emoji / punctuation / digits so a
        // leading 🌟 in "🌟 Spencer" still surfaces "S" rather than the
        // emoji.
        guard let letter = trimmed.first(where: \.isLetter) else { return "?" }
        return String(letter).uppercased()
    }
}

#Preview("InitialLetterAvatarView — Spencer") {
    InitialLetterAvatarView(displayName: "Spencer Adams")
        .padding()
        .background(DODColor.surface)
}

#Preview("InitialLetterAvatarView — fallback") {
    InitialLetterAvatarView(displayName: "🌟")
        .padding()
        .background(DODColor.surface)
}

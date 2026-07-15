/// A pure, `Sendable` value type describing "where am I in an ordered set of
/// steps" — the completion fraction, the "Step X of Y" caption, and the
/// VoiceOver label — with no SwiftUI dependency so it is trivially unit-testable.
///
/// This is the reusable, feature-agnostic sibling of RecipeDetail's private
/// `CookModeProgress` (modelled on it, but without the Cook-Mode-specific
/// `isFinished` "All Done" page). It backs ``StepWalkthroughView`` and is shared
/// so First Cookout (walking coaching/recipe steps) and, later, Cook Mode can
/// present the same "Step X of Y" progress from one tested source of truth.
///
/// All accessors clamp defensively: an empty step list, or a `currentIndex`
/// outside `0..<count`, still yields a sane fraction/caption rather than a
/// divide-by-zero or an out-of-range string.
public struct StepProgress: Equatable, Sendable {

    /// The caller-supplied 0-based index, kept raw (may be out of range).
    public let rawCurrentIndex: Int
    /// The caller-supplied step count, kept raw (may be `0`).
    public let rawCount: Int

    /// - Parameters:
    ///   - currentIndex: The 0-based index of the active step. Values outside
    ///     `0..<count` are clamped into range by the derived accessors.
    ///   - count: The total number of steps. `0` (an empty walkthrough) is
    ///     treated as a single step so callers never divide by zero.
    public init(currentIndex: Int, count: Int) {
        self.rawCurrentIndex = currentIndex
        self.rawCount = count
    }

    /// Step count clamped to at least 1 so the fraction / caption never divide
    /// by zero on an empty step list.
    public var count: Int { max(rawCount, 1) }

    /// The active index clamped into `0..<count`.
    public var activeIndex: Int { min(max(rawCurrentIndex, 0), count - 1) }

    /// Completion fraction in `0...1`: `(activeIndex + 1) / count`. Drives the
    /// slim progress bar's fill width. The first step already shows some
    /// progress (it is not `0`), matching Cook Mode's bar.
    public var fraction: Double { Double(activeIndex + 1) / Double(count) }

    /// `true` when the active step is the first — the point at which a
    /// "Previous" affordance should be disabled.
    public var isFirst: Bool { activeIndex == 0 }

    /// `true` when the active step is the last — the point at which a "Next"
    /// affordance should be disabled.
    public var isLast: Bool { activeIndex == count - 1 }

    /// The visible caption, e.g. `"Step 2 of 5"` (1-based for humans).
    public var caption: String { "Step \(activeIndex + 1) of \(count)" }

    /// The VoiceOver label for the progress element. Kept separate from
    /// ``caption`` so the two can diverge later without breaking callers.
    public var accessibilityLabel: String { "Step \(activeIndex + 1) of \(count)" }
}

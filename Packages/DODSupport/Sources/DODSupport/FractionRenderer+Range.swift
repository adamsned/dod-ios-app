import Foundation

/// DUT-304: range-ingredient scaling. A RANGE ingredient ("2-3 cloves",
/// "1½–2 cups") carries a second quantity behind a range separator. The base
/// `scale(_:by:)` only multiplied the FIRST leading quantity then glued the
/// untouched trailing slice back on, so doubling "2-3 cloves" produced the
/// nonsense "4-3 cloves". This extension scales the upper bound too and
/// re-emits "lo<sep>hi".
///
/// Lives in its own file purely to keep `FractionRenderer.swift` under the
/// 400-line `file_length` ceiling; it shares the same parsing seam
/// (`parseLeadingQuantity` / `renderQuantity`).
extension FractionRenderer {

    /// One scaled range upper-bound parsed off the head of a trailing slice.
    struct ScaledRange {
        /// The matched separator verbatim (e.g. `"-"`, `" – "`).
        let separator: String
        /// The scaled + re-rendered upper bound (e.g. `"6"`).
        let renderedHigh: String
        /// Everything after the second quantity (`" cloves"`), with the
        /// single trailing space `parseLeadingQuantity` consumes re-added.
        let rest: String
    }

    /// Detect `"<sep><quantity>…"` at the head of `trailing`. A range
    /// separator is a hyphen `-`, en-dash `–`, or em-dash `—` with optional
    /// surrounding spaces, followed by a parseable quantity. Returns the
    /// separator verbatim, the scaled upper bound, and the remaining text, or
    /// `nil` when `trailing` is not a range continuation.
    static func scaleRangeContinuation(
        in trailing: Substring,
        by factor: Double
    ) -> ScaledRange? {
        // Scan optional spaces, one range dash, optional spaces — capturing
        // the literal so the re-emit preserves the source's spacing style.
        let beforeDash = scanSpaces(in: trailing, from: trailing.startIndex)
        guard beforeDash < trailing.endIndex, isRangeSeparator(trailing[beforeDash]) else {
            return nil
        }
        let afterDash = scanSpaces(in: trailing, from: trailing.index(after: beforeDash))
        let separator = String(trailing[trailing.startIndex..<afterDash])
        // Parse the upper bound off whatever follows the separator. Copy the
        // slice to a fresh `String` so `parseLeadingQuantity`'s indices belong
        // to a known backing store, then map the consumed character count back
        // onto the live substring (indices don't transfer across copies).
        let secondString = String(trailing[afterDash...])
        guard let high = parseLeadingQuantity(in: secondString) else { return nil }
        let renderedHigh = renderQuantity(high.value * factor)
        let consumed = secondString.distance(from: secondString.startIndex, to: high.afterIndex)
        let secondSlice = trailing[afterDash...]
        let restStart =
            secondSlice.index(
                secondSlice.startIndex,
                offsetBy: consumed,
                limitedBy: secondSlice.endIndex
            ) ?? secondSlice.endIndex
        let rest = secondSlice[restStart...]
        // `parseLeadingQuantity` swallows one trailing space; re-add it unless
        // the second quantity ended the line (range-only input).
        if rest.isEmpty {
            return ScaledRange(separator: separator, renderedHigh: renderedHigh, rest: "")
        }
        return ScaledRange(separator: separator, renderedHigh: renderedHigh, rest: " " + rest)
    }

    /// Returns `" "` when `parseLeadingQuantity` consumed exactly one space
    /// immediately before `afterIndex` (the trailing-slice start), else `""`.
    /// Lets `scale` restore the low-bound→separator gap a spaced range carried
    /// ("1 - 2" must re-emit as "3 - 6", not "3- 6").
    static func consumedSpaceBeforeTrailing(
        in text: String,
        at afterIndex: String.Index
    ) -> String {
        guard afterIndex > text.startIndex else { return "" }
        let priorIndex = text.index(before: afterIndex)
        return text[priorIndex] == " " ? " " : ""
    }

    /// Hyphen / en-dash / em-dash — the range separators we re-emit between
    /// scaled bounds.
    private static func isRangeSeparator(_ character: Character) -> Bool {
        character == "-" || character == "\u{2013}" || character == "\u{2014}"
    }

    private static func scanSpaces(
        in text: Substring,
        from index: Substring.Index
    ) -> Substring.Index {
        var cursor = index
        while cursor < text.endIndex, text[cursor] == " " {
            cursor = text.index(after: cursor)
        }
        return cursor
    }
}

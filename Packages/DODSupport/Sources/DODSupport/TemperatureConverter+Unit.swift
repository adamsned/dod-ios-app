import Foundation

extension TemperatureConverter {

    /// A parsed unit suffix: the scale, how it was spelled (for style
    /// preservation), and the index just past the whole suffix.
    struct UnitSuffix {
        let scale: Scale
        let scaleWord: ScaleWord
        let end: String.Index
    }

    /// Read the explicit unit that immediately follows a number, starting at
    /// `index` (which sits just past the digits). The grammar, all parts
    /// after the number optional except the final scale signal:
    ///
    ///   [spaces] [`°`] [`degrees ` | `degree `] ( scaleWord | scaleLetter )
    ///
    /// A bare `°` or bare `degrees` with no scale letter/word is rejected —
    /// that is the guard that keeps "tilt 90 degrees" and a lone "350°" from
    /// being treated as temperatures. Returns `nil` when no scale signal is
    /// present.
    static func readUnitSuffix(in text: String, from index: String.Index) -> UnitSuffix? {
        var cursor = skipSpaces(in: text, from: index)

        let hadDegreeSymbol = cursor < text.endIndex && text[cursor] == "\u{00B0}"
        if hadDegreeSymbol {
            cursor = text.index(after: cursor)
            cursor = skipSpaces(in: text, from: cursor)
        } else {
            cursor = skipDegreesWord(in: text, from: cursor)
        }

        return readScaleSignal(in: text, from: cursor)
    }

    /// Consume the literal word `degrees` / `degree` plus a trailing space if
    /// present; otherwise return `index` unchanged.
    private static func skipDegreesWord(in text: String, from index: String.Index) -> String.Index {
        let lower = text[index...].lowercased()
        for token in ["degrees ", "degree "] where lower.hasPrefix(token) {
            return text.index(index, offsetBy: token.count)
        }
        return index
    }

    /// Read the terminal scale signal — a spelled-out word
    /// (`fahrenheit` / `celsius`) or a single boundary-bounded letter
    /// (`f` / `c`). Returns `nil` when neither is present so the caller
    /// rejects the candidate.
    private static func readScaleSignal(in text: String, from index: String.Index) -> UnitSuffix? {
        guard index < text.endIndex else { return nil }
        let lower = text[index...].lowercased()

        for (token, scale) in [("fahrenheit", Scale.fahrenheit), ("celsius", Scale.celsius)]
        where lower.hasPrefix(token) {
            let end = text.index(index, offsetBy: token.count)
            guard isWordBoundary(in: text, at: end) else { continue }
            let original = String(text[index..<end])
            return UnitSuffix(scale: scale, scaleWord: .word(original), end: end)
        }

        let scale: Scale
        switch text[index] {
        case "f", "F": scale = .fahrenheit
        case "c", "C": scale = .celsius
        default: return nil
        }
        let end = text.index(after: index)
        // The single letter must end a token — the next character can't be a
        // letter, or "Fresh" / "cups" would read as a unit.
        guard isWordBoundary(in: text, at: end) else { return nil }
        let original = String(text[index..<end])
        return UnitSuffix(scale: scale, scaleWord: .letter(original), end: end)
    }

    /// True when `index` is the end of the string or sits on a non-letter
    /// character — i.e. the preceding token ended on a word boundary.
    private static func isWordBoundary(in text: String, at index: String.Index) -> Bool {
        guard index < text.endIndex else { return true }
        return !text[index].isLetter
    }
}

import Foundation

extension TemperatureConverter {

    /// Walk `text` left to right, emitting one ``Match`` per explicit-unit
    /// temperature (single or range). Non-overlapping and in source order so
    /// the rewrite in ``converting(_:to:)`` can stitch the output linearly.
    static func scan(_ text: String) -> [Match] {
        var matches: [Match] = []
        var cursor = text.startIndex
        while cursor < text.endIndex {
            guard text[cursor].isNumber else {
                cursor = text.index(after: cursor)
                continue
            }
            if let match = readTemperature(in: text, from: cursor) {
                matches.append(match)
                cursor = match.range.upperBound
            } else {
                // Skip the whole numeric run so a non-temperature number
                // (e.g. "350" in "bake at 350") isn't re-probed digit by
                // digit — and so its digits can't seed a spurious match.
                cursor = endOfNumber(in: text, from: cursor)
            }
        }
        return matches
    }

    /// Attempt to read a full temperature occurrence starting at the digit
    /// `start`. Returns `nil` when the number is not followed by an explicit
    /// scale signal (so bare numbers / times / quantities fall through). A
    /// range form is tried first; the single form is the fallback.
    private static func readTemperature(in text: String, from start: String.Index) -> Match? {
        guard let first = readNumber(in: text, from: start) else { return nil }
        if let rangeMatch = readRange(in: text, start: start, first: first) {
            return rangeMatch
        }
        // Single form: "<value><unit>".
        guard let unit = readUnitSuffix(in: text, from: first.range.upperBound) else {
            return nil
        }
        return Match(
            values: [first],
            scale: unit.scale,
            scaleWord: unit.scaleWord,
            separator: nil,
            unitSuffix: String(text[first.range.upperBound..<unit.end]),
            range: start..<unit.end
        )
    }

    /// Range form: "<first><sep><second><unit>" where the explicit unit on
    /// the right end applies to both numbers (e.g. "350-375°F",
    /// "350 to 375°F"). Returns `nil` unless a separator, a second number,
    /// and a trailing unit are all present.
    private static func readRange(in text: String, start: String.Index, first: Value) -> Match? {
        guard
            let separatorEnd = readRangeSeparator(in: text, from: first.range.upperBound),
            let second = readNumber(in: text, from: separatorEnd),
            let unit = readUnitSuffix(in: text, from: second.range.upperBound)
        else {
            return nil
        }
        return Match(
            values: [first, second],
            scale: unit.scale,
            scaleWord: unit.scaleWord,
            separator: String(text[first.range.upperBound..<second.range.lowerBound]),
            unitSuffix: String(text[second.range.upperBound..<unit.end]),
            range: start..<unit.end
        )
    }

    // MARK: - Number scanning

    /// Read one integer-or-decimal magnitude starting at `index`. Returns
    /// `nil` if `index` is not a digit.
    private static func readNumber(in text: String, from index: String.Index) -> Value? {
        guard index < text.endIndex, text[index].isNumber else { return nil }
        var end = endOfDigits(in: text, from: index)
        // Optional single decimal point followed by more digits ("212.0").
        if end < text.endIndex, text[end] == "." {
            let afterDot = text.index(after: end)
            let fractionEnd = endOfDigits(in: text, from: afterDot)
            if fractionEnd > afterDot { end = fractionEnd }
        }
        let literal = String(text[index..<end])
        guard let magnitude = Double(literal) else { return nil }
        return Value(magnitude: magnitude, literal: literal, range: index..<end)
    }

    /// Index just past a run of digits starting at `index`.
    private static func endOfDigits(in text: String, from index: String.Index) -> String.Index {
        var cursor = index
        while cursor < text.endIndex, text[cursor].isNumber {
            cursor = text.index(after: cursor)
        }
        return cursor
    }

    /// Index just past a full number (digits + optional `.` + digits) — used
    /// to skip a rejected numeric run wholesale.
    private static func endOfNumber(in text: String, from index: String.Index) -> String.Index {
        readNumber(in: text, from: index)?.range.upperBound ?? text.index(after: index)
    }

    /// Read a range separator between two numbers: a hyphen / en-dash /
    /// em-dash (with optional surrounding spaces) or the word `to` (space
    /// padded). Returns the index just past the separator, or `nil`.
    private static func readRangeSeparator(in text: String, from index: String.Index) -> String.Index? {
        var cursor = skipSpaces(in: text, from: index)
        guard cursor < text.endIndex else { return nil }
        if isDashSeparator(text[cursor]) {
            cursor = text.index(after: cursor)
            return skipSpaces(in: text, from: cursor)
        }
        // Word separator "to" — must be a standalone token (space-bounded on
        // both sides) so it can't swallow the start of another word.
        guard cursor > index else { return nil }  // required a leading space
        let lower = text[cursor...].lowercased()
        guard lower.hasPrefix("to ") else { return nil }
        let afterTo = text.index(cursor, offsetBy: 2)
        return skipSpaces(in: text, from: afterTo)
    }

    private static func isDashSeparator(_ character: Character) -> Bool {
        character == "-" || character == "\u{2013}" || character == "\u{2014}"
    }

    static func skipSpaces(in text: String, from index: String.Index) -> String.Index {
        var cursor = index
        while cursor < text.endIndex, text[cursor] == " " {
            cursor = text.index(after: cursor)
        }
        return cursor
    }
}

import DODDomain
import DODSupport
import Foundation

/// Extracts a structured `Recipe` from the JSON-LD blocks embedded in a
/// rendered WPRM post page.
///
/// Strategy (plan §3, CL-1):
/// 1. Scan the HTML for every `<script type="application/ld+json">…</script>`
///    block (T-057). No HTML parser dependency — regex is sufficient for
///    WPRM's output and SwiftLint forbids new SPM packages anyway.
/// 2. JSON-decode each block.
/// 3. Walk decoded values looking for an object with `@type == "Recipe"`,
///    including inside `@graph` arrays (T-058).
/// 4. Map fields to `Recipe`, handling multiple `recipeInstructions` shapes
///    per R-4 (T-059).
public enum JSONLDRecipeParser {

    public enum Error: Swift.Error, Equatable {
        /// No `<script type="application/ld+json">` blocks present.
        case noJSONLDBlocks
        /// Blocks present, but none decoded to JSON.
        case noDecodableJSON
        /// Decoded JSON contained no `@type: Recipe` object.
        case notFound
    }

    /// Parse the HTML and return a partially-populated `Recipe` (detail
    /// fields only — id/title/list-data come from REST).
    ///
    /// - Parameters:
    ///   - html: raw rendered HTML.
    ///   - merging: an existing `RecipeListItem` whose id, title, image, etc.
    ///     are stitched onto the detail data per AC-4.11.
    public static func parse(
        html: String,
        merging listItem: RecipeListItem,
        canonicalURL: URL
    ) throws -> Recipe {
        let blocks = extractJSONLDBlocks(in: html)
        guard !blocks.isEmpty else { throw Error.noJSONLDBlocks }

        var anyDecoded = false
        for raw in blocks {
            guard let object = try? JSONSerialization.jsonObject(with: Data(raw.utf8)) else {
                continue
            }
            anyDecoded = true
            if let recipeObject = findRecipeObject(in: object) {
                return mapRecipe(
                    jsonLD: recipeObject,
                    listItem: listItem,
                    canonicalURL: canonicalURL,
                    html: html
                )
            }
        }
        if !anyDecoded { throw Error.noDecodableJSON }
        throw Error.notFound
    }

    // MARK: - Extraction (T-057)

    /// Pull every inner string from `<script type="application/ld+json">…</script>`
    /// blocks. Order-preserving. Robust to extra whitespace and attribute
    /// re-ordering, but assumes the closing `</script>` exists.
    static func extractJSONLDBlocks(in html: String) -> [String] {
        var results: [String] = []
        var cursor = html.startIndex
        let openMarker = "<script"
        let closeMarker = "</script>"
        while cursor < html.endIndex {
            guard let openTagStart = html.range(of: openMarker, range: cursor..<html.endIndex) else {
                break
            }
            guard let openTagEnd = html.range(of: ">", range: openTagStart.upperBound..<html.endIndex) else {
                break
            }
            let attributes = html[openTagStart.upperBound..<openTagEnd.lowerBound]
            let isJSONLD = attributes.range(of: "application/ld+json", options: .caseInsensitive) != nil
            guard let closeTagRange = html.range(of: closeMarker, range: openTagEnd.upperBound..<html.endIndex)
            else {
                break
            }
            if isJSONLD {
                let body = html[openTagEnd.upperBound..<closeTagRange.lowerBound]
                results.append(String(body))
            }
            cursor = closeTagRange.upperBound
        }
        return results
    }

    // MARK: - Recipe-object walk (T-058)

    /// Walk a JSON-LD value (Array, Dict, or scalar) and return the first
    /// dictionary whose `@type` equals "Recipe". Handles `@graph` envelopes.
    static func findRecipeObject(in value: Any) -> [String: Any]? {
        if let dict = value as? [String: Any] {
            if matchesRecipeType(dict["@type"]) {
                return dict
            }
            if let graph = dict["@graph"] {
                return findRecipeObject(in: graph)
            }
        }
        if let array = value as? [Any] {
            for element in array {
                if let found = findRecipeObject(in: element) {
                    return found
                }
            }
        }
        return nil
    }

    /// `@type` can be a string or an array of strings.
    static func matchesRecipeType(_ raw: Any?) -> Bool {
        if let single = raw as? String { return single == "Recipe" }
        // DUT-916: `@type` may be a MIXED array (a stray null/number alongside
        // the strings some WPRM/plugin configs emit). A whole-array
        // `as? [String]` fails on one non-string element, dropping the match so
        // a genuine recipe renders as a plain article — mirror the #606/DUT-214
        // fix and check each element that IS a string.
        if let array = raw as? [Any] { return array.contains { ($0 as? String) == "Recipe" } }
        return false
    }

    // MARK: - Field mapping (T-058, T-059)

    static func mapRecipe(
        jsonLD: [String: Any],
        listItem: RecipeListItem,
        canonicalURL: URL,
        html: String
    ) -> Recipe {
        let (ingredients, instructions) = ingredientsAndInstructions(
            jsonLD: jsonLD,
            html: html
        )
        let prep = parseISO8601Duration(jsonLD["prepTime"] as? String)
        let cook = parseISO8601Duration(jsonLD["cookTime"] as? String)
        let total = parseISO8601Duration(jsonLD["totalTime"] as? String)
        let servings = parseServings(jsonLD["recipeYield"])
        let nutrition = mapNutrition(jsonLD["nutrition"])
        let video = mapVideo(jsonLD["video"])
        let recipeCategory = mapStringOrArray(jsonLD["recipeCategory"])
        let recipeCuisine = mapStringOrArray(jsonLD["recipeCuisine"])
        let suitableForDiet = mapStringOrArray(jsonLD["suitableForDiet"])
        let author = mapAuthorName(jsonLD["author"])

        return Recipe(
            id: listItem.id,
            slug: canonicalURL.lastPathComponent,
            title: listItem.title,
            excerpt: listItem.excerpt,
            canonicalURL: canonicalURL,
            heroImage: listItem.heroImage,
            heroImageLargeURL: nil,
            categoryIDs: listItem.categoryIDs ?? [],
            publishedAt: listItem.publishedAt,
            ingredients: ingredients,
            instructions: instructions,
            prepTime: prep,
            cookTime: cook,
            totalTime: total,
            servings: servings,
            nutrition: nutrition,
            video: video,
            recipeCategory: recipeCategory,
            recipeCuisine: recipeCuisine,
            suitableForDiet: suitableForDiet,
            author: author
        )
    }

    /// Resolve the ingredient + instruction lists, with the DUT-42 WPRM
    /// fallback applied **per field**. JSON-LD is the primary source; only when
    /// a field's JSON-LD list is empty do we fill it from the page's WP Recipe
    /// Maker card (some posts ship a `Recipe` node that omits
    /// `recipeIngredient` / `recipeInstructions` even though the data is in the
    /// rendered WPRM HTML — confirmed `dutch-oven-7-can-soup`, 2026-06-04). A
    /// recipe with complete JSON-LD is unchanged: the WPRM card is scanned
    /// **only** when at least one field is empty (the scan is skipped entirely
    /// for the common complete-JSON-LD case).
    static func ingredientsAndInstructions(
        jsonLD: [String: Any],
        html: String
    ) -> (ingredients: [RecipeIngredient], instructions: [RecipeInstruction]) {
        var ingredients = mapIngredients(jsonLD["recipeIngredient"])
        var instructions = mapInstructions(jsonLD["recipeInstructions"])
        guard ingredients.isEmpty || instructions.isEmpty else {
            return (ingredients, instructions)
        }
        let card = WPRMRecipeCardParser.parse(html: html)
        if ingredients.isEmpty {
            ingredients = RecipeIngredient.list(from: card.ingredients)
        }
        if instructions.isEmpty {
            instructions = card.instructions.enumerated().map { index, text in
                RecipeInstruction(step: index + 1, text: text)
            }
        }
        return (ingredients, instructions)
    }

    static func mapIngredients(_ raw: Any?) -> [RecipeIngredient] {
        // Drop blank/whitespace-only entries so comments, section headers, and
        // stray markup that sanitize to empty don't become garbage Shopping List
        // rows (DUT-587). Mirrors the WPRM card parser's non-empty guard.
        //
        // `raw as? [String]` succeeds only when EVERY element is a String, so a
        // single malformed entry (a stray JSON `null`/number/object some WPRM
        // configs emit, e.g. an ingredient-group header) failed the whole-array
        // cast and silently dropped ALL ingredients. Cast to `[Any]` and keep
        // only the elements that are Strings, mirroring the `mapVideo` DUT-214
        // fix for the identical all-or-nothing cast failure mode.
        guard let array = raw as? [Any] else { return [] }
        let strings = array.compactMap { $0 as? String }
        // DUT-705: enumerate so a legitimately repeated ingredient line gets an
        // index-salted, distinct-but-stable id (equal text at different
        // positions must not collide on one `id`).
        return strings.enumerated().compactMap {
            RecipeIngredient(nonBlank: HTMLSanitizer.plainText(from: $0.element), index: $0.offset)
        }
    }

    /// Handle the three shapes WPRM/Schema.org can emit:
    /// - `[String]`
    /// - `[HowToStep]` — each `{ "@type": "HowToStep", "text": "...", ... }`
    /// - `[HowToSection]` — each contains a nested `itemListElement: [HowToStep]`
    static func mapInstructions(_ raw: Any?) -> [RecipeInstruction] {
        guard let array = raw as? [Any] else { return [] }
        var steps: [String] = []
        for element in array {
            collectInstructionTexts(from: element, into: &steps)
        }
        return steps.enumerated().map { index, text in
            RecipeInstruction(step: index + 1, text: HTMLSanitizer.plainText(from: text))
        }
    }

    private static func collectInstructionTexts(from element: Any, into steps: inout [String]) {
        if let text = element as? String {
            steps.append(text)
            return
        }
        guard let dict = element as? [String: Any] else { return }
        // DUT-916: tolerate a mixed `@type` array (per-element, not whole-cast).
        let type =
            (dict["@type"] as? String)
            ?? (dict["@type"] as? [Any])?.compactMap { $0 as? String }.first
            ?? ""
        switch type {
        case "HowToStep":
            if let text = dict["text"] as? String {
                steps.append(text)
            } else if let name = dict["name"] as? String {
                steps.append(name)
            }
        case "HowToSection":
            if let items = dict["itemListElement"] as? [Any] {
                for item in items {
                    collectInstructionTexts(from: item, into: &steps)
                }
            }
        default:
            // Unknown — fall back to a "text" field if present.
            if let text = dict["text"] as? String {
                steps.append(text)
            }
        }
    }

    /// Decode ISO8601 durations like "PT15M", "PT1H30M".
    static func parseISO8601Duration(_ raw: String?) -> Duration? {
        // DUT-356: accept an optional date portion before the "T" (e.g. "P0DT8H"
        // for an 8-hour cook), not just bare "PT…". `D` is days; `H`/`M`/`S` are
        // valid only in the time part ("M" in the date part means months, which
        // recipes don't use → reject). A trailing digit run with no unit is
        // malformed and rejected rather than silently dropped.
        guard let raw, raw.hasPrefix("P") else { return nil }
        let body = raw.dropFirst()  // drop "P"
        var seconds: Int64 = 0
        var buffer = ""
        var inTimePart = false
        for character in body {
            if character == "T" {
                guard buffer.isEmpty else { return nil }
                inTimePart = true
                continue
            }
            if character.isNumber {
                buffer.append(character)
                continue
            }
            guard let value = Int64(buffer),
                let multiplier = iso8601UnitMultiplier(character, inTimePart: inTimePart)
            else { return nil }
            // DUT-518: scraped JSON-LD is untrusted — a giant digit run (e.g.
            // "PT99999999999999H") overflows Int64 under trapping `*`/`+` and
            // crashes. Report overflow and bail; the caller treats nil as
            // "no duration".
            let (product, mulOverflow) = value.multipliedReportingOverflow(by: multiplier)
            guard !mulOverflow else { return nil }
            let (sum, addOverflow) = seconds.addingReportingOverflow(product)
            guard !addOverflow else { return nil }
            seconds = sum
            buffer.removeAll()
        }
        guard buffer.isEmpty else { return nil }
        return seconds > 0 ? .seconds(seconds) : nil
    }

    /// Seconds-per-unit for an ISO-8601 duration designator, or nil if the unit
    /// isn't valid in its position (e.g. `D` after the `T`, or `H`/`M`/`S` before
    /// it). `M` before `T` is months — unsupported for recipes, so nil.
    private static func iso8601UnitMultiplier(_ unit: Character, inTimePart: Bool) -> Int64? {
        switch unit {
        case "D" where !inTimePart: return 86_400
        case "H" where inTimePart: return 3600
        case "M" where inTimePart: return 60
        case "S" where inTimePart: return 1
        default: return nil
        }
    }
}

extension RecipeIngredient {
    /// Failable init used by ``JSONLDRecipeParser/mapIngredients(_:)`` to drop
    /// blank/whitespace-only ingredient lines (DUT-587) — returns nil when the
    /// text trims to empty so a garbage Shopping List row is never created.
    fileprivate init?(nonBlank text: String, index: Int) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        self.init(text: text, index: index)
    }
}

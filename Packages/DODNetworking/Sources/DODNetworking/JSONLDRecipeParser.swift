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
        if let multi = raw as? [String] { return multi.contains("Recipe") }
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

        return Recipe(
            id: listItem.id,
            slug: canonicalURL.lastPathComponent,
            title: listItem.title,
            excerpt: listItem.excerpt,
            canonicalURL: canonicalURL,
            heroImage: listItem.heroImage,
            heroImageLargeURL: nil,
            categoryIDs: [],
            publishedAt: listItem.publishedAt,
            ingredients: ingredients,
            instructions: instructions,
            prepTime: prep,
            cookTime: cook,
            totalTime: total,
            servings: servings,
            nutrition: nutrition,
            video: video
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
            ingredients = card.ingredients.map { RecipeIngredient(text: $0) }
        }
        if instructions.isEmpty {
            instructions = card.instructions.enumerated().map { index, text in
                RecipeInstruction(step: index + 1, text: text)
            }
        }
        return (ingredients, instructions)
    }

    static func mapIngredients(_ raw: Any?) -> [RecipeIngredient] {
        guard let array = raw as? [String] else { return [] }
        return array.map { RecipeIngredient(text: HTMLSanitizer.plainText(from: $0)) }
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
        let type = (dict["@type"] as? String) ?? (dict["@type"] as? [String])?.first ?? ""
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
        guard let raw, raw.hasPrefix("PT") else { return nil }
        let body = raw.dropFirst(2)
        var seconds: Int64 = 0
        var buffer = ""
        for character in body {
            if character.isNumber {
                buffer.append(character)
            } else {
                guard let value = Int64(buffer) else { return nil }
                switch character {
                case "H": seconds += value * 3600
                case "M": seconds += value * 60
                case "S": seconds += value
                default: return nil
                }
                buffer.removeAll()
            }
        }
        return seconds > 0 ? .seconds(seconds) : nil
    }

    /// `recipeYield` may be a number, a string, or an array of strings.
    static func parseServings(_ raw: Any?) -> Int? {
        if let int = raw as? Int { return int }
        if let double = raw as? Double { return Int(double) }
        if let string = raw as? String { return Int(string) ?? Int(string.split(separator: " ").first ?? "") }
        if let array = raw as? [String], let first = array.first { return Int(first) }
        return nil
    }

    static func mapNutrition(_ raw: Any?) -> RecipeNutrition? {
        guard let dict = raw as? [String: Any] else { return nil }
        return RecipeNutrition(
            calories: dict["calories"] as? String,
            servingSize: dict["servingSize"] as? String,
            proteinGrams: dict["proteinContent"] as? String,
            carbsGrams: dict["carbohydrateContent"] as? String,
            fatGrams: dict["fatContent"] as? String
        )
    }

    static func mapVideo(_ raw: Any?) -> RecipeVideo? {
        let dict: [String: Any]?
        if let object = raw as? [String: Any] {
            dict = object
        } else if let array = raw as? [[String: Any]] {
            dict = array.first
        } else {
            dict = nil
        }
        guard let dict else { return nil }

        // contentUrl is preferred; fall back to embedUrl.
        let urlString = (dict["contentUrl"] as? String) ?? (dict["embedUrl"] as? String)
        guard let urlString, let url = URL(string: urlString) else { return nil }

        let thumbnail =
            (dict["thumbnailUrl"] as? String).flatMap { URL(string: $0) }
            ?? ((dict["thumbnailUrl"] as? [String])?.first).flatMap { URL(string: $0) }

        let duration = parseISO8601Duration(dict["duration"] as? String)

        return RecipeVideo(url: url, thumbnailURL: thumbnail, duration: duration)
    }
}

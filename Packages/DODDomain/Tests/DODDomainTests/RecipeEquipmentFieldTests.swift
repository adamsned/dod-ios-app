import Foundation
import Testing

@testable import DODDomain

@Test func defaultsToEmpty() {
    let recipe = Recipe(
        id: 1,
        slug: "test",
        title: "Test Recipe",
        excerpt: "Test excerpt",
        canonicalURL: URL(string: "https://example.com")!,
        publishedAt: Date()
    )

    #expect(recipe.equipment.isEmpty)
}

@Test func oldPayloadWithoutKeyDecodes() throws {
    // Build a recipe with only required args
    let originalRecipe = Recipe(
        id: 1,
        slug: "test",
        title: "Test Recipe",
        excerpt: "Test excerpt",
        canonicalURL: URL(string: "https://example.com")!,
        publishedAt: Date()
    )

    // Encode it to JSON
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(originalRecipe)

    // Convert to dictionary, remove the equipment key, then back to JSON
    let jsonDict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    var modifiedDict = jsonDict ?? [:]
    modifiedDict.removeValue(forKey: "equipment")
    let modifiedData = try JSONSerialization.data(withJSONObject: modifiedDict)

    // Decode it back
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decodedRecipe = try decoder.decode(Recipe.self, from: modifiedData)

    // Verify equipment is empty (default value when key is missing)
    #expect(decodedRecipe.equipment.isEmpty)
}

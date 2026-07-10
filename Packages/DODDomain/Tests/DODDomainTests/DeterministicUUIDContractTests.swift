import Testing
@testable import DODDomain

@Suite struct DeterministicUUIDContractTests {

    @Test func determinismWithRepeatedInput() {
        let input = "2 cups flour"
        let uuid1 = DeterministicUUID.from(input)
        let uuid2 = DeterministicUUID.from(input)

        #expect(uuid1 == uuid2, "DeterministicUUID should produce the same UUID for the same input")
    }

    @Test func determinismWithEmptyString() {
        let emptyStringUUID1 = DeterministicUUID.from("")
        let emptyStringUUID2 = DeterministicUUID.from("")

        #expect(
            emptyStringUUID1 == emptyStringUUID2,
            "DeterministicUUID should produce the same UUID for an empty string"
        )
    }

    @Test func determinismWithEmojiAndUnicode() {
        let emojiInput = "Flour 🌟"
        let emojiUUID1 = DeterministicUUID.from(emojiInput)
        let emojiUUID2 = DeterministicUUID.from(emojiInput)

        #expect(
            emojiUUID1 == emojiUUID2,
            "DeterministicUUID should produce the same UUID for emoji/unicode input"
        )
    }

    @Test func distinctnessWithVariedInputs() {
        let ingredients = [
            "flour",
            "sugar",
            "eggs",
            "milk",
            "butter",
            "vanilla extract",
            "cocoa powder",
            "baking soda",
        ]

        let uuids = ingredients.map { DeterministicUUID.from($0) }
        let uuidSet = Set(uuids)

        #expect(uuidSet.count == ingredients.count, "All distinct inputs should produce unique UUIDs")
    }

    @Test func caseInsensitivityBoundary() {
        let uuid1 = DeterministicUUID.from("Flour")
        let uuid2 = DeterministicUUID.from("flour")

        #expect(uuid1 != uuid2, "DeterministicUUID should be case-sensitive")
    }

    @Test func whitespaceSensitivityBoundary() {
        let uuid1 = DeterministicUUID.from("a b")
        let uuid2 = DeterministicUUID.from("ab")

        #expect(uuid1 != uuid2, "DeterministicUUID should be whitespace-sensitive")
    }

    @Test func wellFormednessVersionNibble() {
        let sampleInput = "Sample Input for UUID Test"
        let uuid = DeterministicUUID.from(sampleInput)

        // In UUID string format: xxxxxxxx-xxxx-5xxx-[89ab]xxx-xxxxxxxxxxxx
        // The version is at position 14 (3rd char of 3rd group)
        let uuidString = uuid.uuidString
        let versionCharIndex = uuidString.index(uuidString.startIndex, offsetBy: 14)
        let versionChar = uuidString[versionCharIndex]

        #expect(versionChar == "5", "UUID version character should be 5 for name-based UUID")
    }

    @Test func wellFormednessVariantBits() {
        let sampleInput = "Sample Input for UUID Test"
        let uuid = DeterministicUUID.from(sampleInput)

        // In UUID string format, the variant is at position 19 (1st char of 4th group)
        // RFC 4122 variant uses 8, 9, a, or b (0b10xx in binary)
        let uuidString = uuid.uuidString
        let variantCharIndex = uuidString.index(uuidString.startIndex, offsetBy: 19)
        let variantChar = uuidString[variantCharIndex]

        let validVariantChars = ["8", "9", "a", "A", "b", "B"]
        #expect(
            validVariantChars.contains(String(variantChar)),
            "UUID variant should be RFC 4122 compliant (8, 9, a, or b)"
        )
    }
}

import Testing

@testable import DODSupport

@Suite("StringHasher.sha256Hex") struct StringHasherTests {

    @Test func digestIsSixtyFourHexCharacters() {
        let digest = StringHasher.sha256Hex("anything")
        #expect(digest.count == 64)
        #expect(digest.allSatisfy { $0.isHexDigit })
    }

    @Test func sameInputProducesSameDigest() {
        let one = StringHasher.sha256Hex("dutch oven peach cobbler")
        let two = StringHasher.sha256Hex("dutch oven peach cobbler")
        #expect(one == two)
    }

    @Test func oneCharacterDifferenceChangesDigest() {
        let one = StringHasher.sha256Hex("garlic butter corn")
        let two = StringHasher.sha256Hex("garlic butter horn")
        #expect(one != two)
    }

    @Test func leadingTrailingWhitespaceIsIgnored() {
        let canonical = StringHasher.sha256Hex("apple crisp")
        let padded = StringHasher.sha256Hex("   apple crisp\n")
        #expect(canonical == padded)
    }

    @Test func caseIsIgnored() {
        let lower = StringHasher.sha256Hex("Beer Battered Fish")
        let upper = StringHasher.sha256Hex("BEER BATTERED FISH")
        #expect(lower == upper)
    }
}

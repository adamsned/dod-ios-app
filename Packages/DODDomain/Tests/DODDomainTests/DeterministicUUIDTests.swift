import Testing

@testable import DODDomain

@Suite struct DeterministicUUIDTests {
    @Test func determinism() {
        let uuid1 = DeterministicUUID.from("test")
        let uuid2 = DeterministicUUID.from("test")
        #expect(uuid1 == uuid2)
    }

    @Test func distinctInputsProduceDistinctUUIDs() {
        let uuid1 = DeterministicUUID.from("text1")
        let uuid2 = DeterministicUUID.from("text2")
        #expect(uuid1 != uuid2)
    }

    @Test func rfc4122Version5AndVariantCorrect() {
        let uuid = DeterministicUUID.from("test")
        let uuidString = uuid.uuidString
        // Version 5 means character at index 14 should be '5'
        #expect(uuidString[uuidString.index(uuidString.startIndex, offsetBy: 14)] == "5")
        // Variant bits (10) means character at index 19 should be in '89ab'
        let variantChar = uuidString[uuidString.index(uuidString.startIndex, offsetBy: 19)]
        #expect("89abAB".contains(variantChar))
    }

    @Test func emptyStringInputWorksDeterministically() {
        let uuid1 = DeterministicUUID.from("")
        let uuid2 = DeterministicUUID.from("")
        #expect(uuid1 == uuid2)
    }

    @Test func whitespaceDifferenceProducesDifferentUUIDs() {
        let uuid1 = DeterministicUUID.from("text")
        let uuid2 = DeterministicUUID.from(" text ")
        #expect(uuid1 != uuid2)
    }

    @Test func twoSpacesDifferenceProducesDifferentUUIDs() {
        let uuid1 = DeterministicUUID.from("1 cup flour")
        let uuid2 = DeterministicUUID.from("1  cup flour")
        #expect(uuid1 != uuid2)
    }
}

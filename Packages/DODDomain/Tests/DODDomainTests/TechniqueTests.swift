import Testing

@testable import DODDomain

@Test
func detectTechniques() {
    // Test the example from the ticket
    #expect(Technique.detect(in: "Sear the steak, then braise 2 hours") == [.sear, .braise])

    // Test empty case
    #expect(Technique.detect(in: "Mix and serve").isEmpty)

    // Test single technique
    #expect(Technique.detect(in: "BAKE at 400") == [.bake])

    // Test pastTense property
    #expect(Technique.sear.pastTense == "seared")
}

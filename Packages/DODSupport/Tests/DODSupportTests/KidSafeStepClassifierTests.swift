import Testing

@testable import DODSupport

@Suite("KidSafeStepClassifier")
struct KidSafeStepClassifierTests {

    @Test("stirSauceIsKidSafe")
    func stirSauceIsKidSafe() {
        #expect(KidSafeStepClassifier.isKidSafe("Stir the sauce until combined.") == true)
    }

    @Test("addCheeseIsKidSafe")
    func addCheeseIsKidSafe() {
        #expect(KidSafeStepClassifier.isKidSafe("Add the shredded cheese on top.") == true)
    }

    @Test("chopOnionIsGrownUp")
    func chopOnionIsGrownUp() {
        #expect(KidSafeStepClassifier.isKidSafe("Chop the onion finely.") == false)
    }

    @Test("ovenIsGrownUp")
    func ovenIsGrownUp() {
        #expect(KidSafeStepClassifier.isKidSafe("Place in the oven at 350°F.") == false)
    }

    @Test("caseInsensitive")
    func caseInsensitive() {
        #expect(KidSafeStepClassifier.isKidSafe("Carefully SLICE the bread.") == false)
    }

    @Test("emptyStringIsKidSafe")
    func emptyStringIsKidSafe() {
        #expect(KidSafeStepClassifier.isKidSafe("") == true)
    }
}

import Testing

@testable import DODFeatureRecipeDetail

@Suite("Cook Mode posture (DUT-1017)")
struct CookModePostureTests {

    @Test func resolveHingeAngleNil() {
        #expect(CookModePosture.resolve(hingeAngle: nil) == .flat)
    }

    @Test func resolveHingeAngle90() {
        #expect(CookModePosture.resolve(hingeAngle: 90) == .tent)
    }

    @Test func resolveHingeAngle60() {
        #expect(CookModePosture.resolve(hingeAngle: 60) == .tent)
    }

    @Test func resolveHingeAngle120() {
        #expect(CookModePosture.resolve(hingeAngle: 120) == .tent)
    }

    @Test func resolveHingeAngle30() {
        #expect(CookModePosture.resolve(hingeAngle: 30) == .flat)
    }

    @Test func resolveHingeAngle180() {
        #expect(CookModePosture.resolve(hingeAngle: 180) == .flat)
    }

    @Test func tentUsesTwoPaneIsFinishedTrue() {
        #expect(CookModePosture.tent.usesTwoPane(isFinished: true) == false)
    }

    @Test func tentUsesTwoPaneIsFinishedFalse() {
        #expect(CookModePosture.tent.usesTwoPane(isFinished: false) == true)
    }

    @Test func flatUsesTwoPaneIsFinishedFalse() {
        #expect(CookModePosture.flat.usesTwoPane(isFinished: false) == false)
    }
}

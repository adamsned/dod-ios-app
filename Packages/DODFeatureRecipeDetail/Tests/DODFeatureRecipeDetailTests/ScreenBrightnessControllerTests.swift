import Testing

@testable import DODFeatureRecipeDetail

@MainActor
@Suite
struct ScreenBrightnessControllerTests {

    @Test func systemControllerClampsToUnitRange() {
        let controller = SystemScreenBrightnessController()
        let original = controller.brightness

        controller.brightness = 5
        #expect(controller.brightness <= 1)

        controller.brightness = -2
        #expect(controller.brightness >= 0)

        controller.brightness = original
    }
}

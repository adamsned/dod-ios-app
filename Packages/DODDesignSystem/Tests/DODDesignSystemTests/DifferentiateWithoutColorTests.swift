import Testing

@testable import DODDesignSystem

@Suite("Differentiate without color") struct DifferentiateWithoutColorTests {
    @Test func borderOnlyWhenSettingEnabled() {
        #expect(StatusOutlineModifier.borderWidth(differentiate: true) == 2)
        #expect(StatusOutlineModifier.borderWidth(differentiate: false) == 0)
    }
}

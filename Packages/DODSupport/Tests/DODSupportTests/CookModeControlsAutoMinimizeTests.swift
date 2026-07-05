import Testing

@testable import DODSupport

/// L1 coverage for the DUT-596 Cook Mode auto-minimize preference: the option
/// set, the "Never" / "N Seconds" labelling, and the pure scheduling decision.
@Suite("CookModeControlsAutoMinimize (DUT-596)")
struct CookModeControlsAutoMinimizeTests {

    @Test func defaultIsFiveAndPresentInOptions() {
        #expect(CookModeControlsAutoMinimize.defaultSeconds == 5)
        #expect(CookModeControlsAutoMinimize.options.contains(CookModeControlsAutoMinimize.defaultSeconds))
    }

    @Test func optionsAreZeroThreeFiveTen() {
        #expect(CookModeControlsAutoMinimize.options == [0, 3, 5, 10])
    }

    @Test func labelForZeroIsNever() {
        #expect(CookModeControlsAutoMinimize.label(for: 0) == "Never")
    }

    @Test func labelForPositiveIsSeconds() {
        #expect(CookModeControlsAutoMinimize.label(for: 3) == "3 Seconds")
        #expect(CookModeControlsAutoMinimize.label(for: 5) == "5 Seconds")
        #expect(CookModeControlsAutoMinimize.label(for: 10) == "10 Seconds")
    }

    @Test func shouldAutoMinimizeOnlyForPositiveDelays() {
        #expect(CookModeControlsAutoMinimize.shouldAutoMinimize(afterSeconds: 0) == false)
        #expect(CookModeControlsAutoMinimize.shouldAutoMinimize(afterSeconds: -1) == false)
        #expect(CookModeControlsAutoMinimize.shouldAutoMinimize(afterSeconds: 5) == true)
        #expect(CookModeControlsAutoMinimize.shouldAutoMinimize(afterSeconds: 10) == true)
    }
}

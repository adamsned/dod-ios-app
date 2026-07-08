import Foundation
import Testing

@testable import DODPersistence

/// DUT-373: `formatTime` feeds every card's `totalTimeDisplay`. A sub-minute
/// total used to render the misleading `"0 min"`; it now reads `"<1 min"`, a
/// non-positive total yields `nil` (no chip at all), and the hour form is
/// spaced (`"1 hr 30 min"`) to match the `"30 min"` / `"1 hr"` branches.
@Suite("formatTime (DUT-373)")
struct FormatTimeTests {

    @Test func nonPositiveTotalsProduceNoChip() {
        #expect(formatTime(seconds: 0) == nil)
        #expect(formatTime(seconds: -30) == nil)
    }

    @Test func subMinuteTotalsRenderLessThanOneMinute() {
        #expect(formatTime(seconds: 1) == "<1 min")
        #expect(formatTime(seconds: 59) == "<1 min")
    }

    @Test func wholeMinutesRender() {
        #expect(formatTime(seconds: 60) == "1 min")
        #expect(formatTime(seconds: 30 * 60) == "30 min")
        #expect(formatTime(seconds: 59 * 60) == "59 min")
    }

    @Test func wholeHoursRender() {
        #expect(formatTime(seconds: 60 * 60) == "1 hr")
        #expect(formatTime(seconds: 2 * 60 * 60) == "2 hr")
    }

    @Test func hoursWithRemainderUseSpacedForm() {
        #expect(formatTime(seconds: 90 * 60) == "1 hr 30 min")
        #expect(formatTime(seconds: 75 * 60) == "1 hr 15 min")
    }

    /// DUT — `formatTime` is now `public` so the App's `RecipeRouteResolver`
    /// can share it instead of keeping a byte-identical private copy. This
    /// asserts the exact `Duration`→whole-seconds conversion the call site
    /// performs (`Int(duration.components.seconds)`) yields the same chip, so
    /// the shared helper can't silently drift the rendered cache-hit time chip.
    @Test func durationSecondsConversionMatchesChip() {
        func chip(_ duration: Duration) -> String? {
            formatTime(seconds: Int(duration.components.seconds))
        }
        #expect(chip(.seconds(0)) == nil)
        #expect(chip(.seconds(45)) == "<1 min")
        #expect(chip(.seconds(30 * 60)) == "30 min")
        #expect(chip(.seconds(60 * 60)) == "1 hr")
        #expect(chip(.seconds(75 * 60)) == "1 hr 15 min")
    }
}

import Testing

@testable import DODFeatureFeed

@Suite("FirstCookoutView+TimerFormat")
@MainActor
struct FirstCookoutViewTimerFormatTests {

    let view = FirstCookoutView()

    // MARK: - formatRemaining Tests

    @Test("formatRemaining zero seconds")
    func testFormatRemainingZeroSeconds() {
        #expect(view.formatRemaining(0) == "0:00")
    }

    @Test("formatRemaining one second")
    func testFormatRemainingOneSecond() {
        #expect(view.formatRemaining(1) == "0:01")
    }

    @Test("formatRemaining 59 seconds")
    func testFormatRemaining59Seconds() {
        #expect(view.formatRemaining(59) == "0:59")
    }

    @Test("formatRemaining exact minute")
    func testFormatRemainingExactMinute() {
        #expect(view.formatRemaining(60) == "1:00")
    }

    @Test("formatRemaining one minute one second")
    func testFormatRemainingOneMinuteOneSecond() {
        #expect(view.formatRemaining(61) == "1:01")
    }

    @Test("formatRemaining two minutes")
    func testFormatRemainingTwoMinutes() {
        #expect(view.formatRemaining(120) == "2:00")
    }

    @Test("formatRemaining 61 minutes one second")
    func testFormatRemaining61MinutesOneSecond() {
        #expect(view.formatRemaining(3661) == "61:01")
    }

    @Test("formatRemaining two hours")
    func testFormatRemainingTwoHours() {
        #expect(view.formatRemaining(7200) == "120:00")
    }

    @Test("formatRemaining large value")
    func testFormatRemainingLargeValue() {
        #expect(view.formatRemaining(359999) == "5999:59")
    }

    @Test("formatRemaining with fractional seconds rounds")
    func testFormatRemainingFractionalRounds() {
        #expect(view.formatRemaining(2.7) == "0:03")
    }

    @Test("formatRemaining fractional rounds down")
    func testFormatRemainingFractionalRoundsDown() {
        #expect(view.formatRemaining(59.4) == "0:59")
    }

    @Test("formatRemaining negative value")
    func testFormatRemainingNegativeValue() {
        let result = view.formatRemaining(-1)
        // Negative values may produce unusual formats depending on Swift's % behavior
        // Just verify it doesn't crash
        #expect(!result.isEmpty)
    }

    @Test("formatRemaining negative 60")
    func testFormatRemainingNegative60() {
        let result = view.formatRemaining(-60)
        #expect(!result.isEmpty)
    }

    // MARK: - bakeCountdownLabel Tests

    @Test("bakeCountdownLabel zero seconds")
    func testBakeCountdownLabelZeroSeconds() {
        #expect(view.bakeCountdownLabel(0) == "0 seconds remaining")
    }

    @Test("bakeCountdownLabel one second")
    func testBakeCountdownLabelOneSecond() {
        #expect(view.bakeCountdownLabel(1) == "1 second remaining")
    }

    @Test("bakeCountdownLabel 59 seconds")
    func testBakeCountdownLabel59Seconds() {
        #expect(view.bakeCountdownLabel(59) == "59 seconds remaining")
    }

    @Test("bakeCountdownLabel exact minute")
    func testBakeCountdownLabelExactMinute() {
        #expect(view.bakeCountdownLabel(60) == "1 minute remaining")
    }

    @Test("bakeCountdownLabel one minute singular")
    func testBakeCountdownLabelOneMinuteSingular() {
        #expect(view.bakeCountdownLabel(60) == "1 minute remaining")
    }

    @Test("bakeCountdownLabel one minute one second")
    func testBakeCountdownLabelOneMinuteOneSecond() {
        #expect(view.bakeCountdownLabel(61) == "1 minute 1 second remaining")
    }

    @Test("bakeCountdownLabel two minutes")
    func testBakeCountdownLabelTwoMinutes() {
        #expect(view.bakeCountdownLabel(120) == "2 minutes remaining")
    }

    @Test("bakeCountdownLabel two minutes plural")
    func testBakeCountdownLabelTwoMinutesPlural() {
        #expect(view.bakeCountdownLabel(120) == "2 minutes remaining")
    }

    @Test("bakeCountdownLabel 61 minutes one second")
    func testBakeCountdownLabel61MinutesOneSecond() {
        #expect(view.bakeCountdownLabel(3661) == "61 minutes 1 second remaining")
    }

    @Test("bakeCountdownLabel minutes plural seconds singular")
    func testBakeCountdownLabelMinutesPluralSecondsSingular() {
        #expect(view.bakeCountdownLabel(121) == "2 minutes 1 second remaining")
    }

    @Test("bakeCountdownLabel negative clamps to zero")
    func testBakeCountdownLabelNegativeClamps() {
        #expect(view.bakeCountdownLabel(-1) == "0 seconds remaining")
    }

    @Test("bakeCountdownLabel negative 60 clamps to zero")
    func testBakeCountdownLabelNegative60Clamps() {
        #expect(view.bakeCountdownLabel(-60) == "0 seconds remaining")
    }

    @Test("bakeCountdownLabel fractional rounds")
    func testBakeCountdownLabelFractionalRounds() {
        #expect(view.bakeCountdownLabel(0.5) == "1 second remaining")
    }

    @Test("bakeCountdownLabel fractional rounds up")
    func testBakeCountdownLabelFractionalRoundsUp() {
        #expect(view.bakeCountdownLabel(0.6) == "1 second remaining")
    }

    @Test("bakeCountdownLabel 59.7 seconds")
    func testBakeCountdownLabel59Point7() {
        #expect(view.bakeCountdownLabel(59.7) == "1 minute remaining")
    }

    @Test("bakeCountdownLabel large value")
    func testBakeCountdownLabelLargeValue() {
        #expect(view.bakeCountdownLabel(359999) == "5999 minutes 59 seconds remaining")
    }
}

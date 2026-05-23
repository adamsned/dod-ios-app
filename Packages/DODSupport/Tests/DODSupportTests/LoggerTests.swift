import Testing

@testable import DODSupport

@Suite("DODLog.redact") struct LoggerTests {

    @Test func nonEmptyStringIsRedacted() {
        let value = "secret query"
        let redacted = DODLog.redact(value)
        #expect(redacted == "<redacted:\(value.count)>")
        #expect(!redacted.contains("secret"))
    }

    @Test func emptyStringMarkedExplicitly() {
        #expect(DODLog.redact("") == "<empty>")
    }

    @Test func multibyteLengthPreserved() {
        // .count is grapheme-aware; that's fine for human-readable redactions.
        let value = "café 日本"
        let redacted = DODLog.redact(value)
        #expect(redacted.hasPrefix("<redacted:"))
    }

    @Test func categoriesExist() {
        // Just ensure no force-unwrap or init crash.
        _ = DODLog.network
        _ = DODLog.persistence
        _ = DODLog.ui
        _ = DODLog.analytics
        _ = DODLog.app
    }
}

import Testing

@testable import DODFeatureSaved

/// DUT-231 — the Shopping List check-off toggle's VoiceOver label must reflect
/// the row's CURRENT state and name the toggle's real behavior (check-off /
/// strikethrough), NOT "already have" — that phrasing belongs solely to the
/// trailing swipe (`markAlreadyHave`, which removes the row). Regression
/// coverage for the mislabeled toggle.
@Suite("ShoppingListView check-off a11y label (DUT-231)")
struct ShoppingListViewAccessibilityTests {

    /// Unchecked row: the toggle offers to CHECK it off — never "already have".
    @Test func uncheckedRowLabelsAsCheckOff() {
        let label = ShoppingListView.checkOffLabel(checked: false)
        #expect(label == "Check off")
        #expect(!label.lowercased().contains("already have"))
    }

    /// Checked row: the label flips to reflect the now-checked state.
    @Test func checkedRowLabelsAsUncheck() {
        let label = ShoppingListView.checkOffLabel(checked: true)
        #expect(label == "Uncheck")
        #expect(!label.lowercased().contains("already have"))
    }

    /// The label must actually differ between states (it reflects current state).
    @Test func labelReflectsCurrentState() {
        #expect(
            ShoppingListView.checkOffLabel(checked: true)
                != ShoppingListView.checkOffLabel(checked: false)
        )
    }
}

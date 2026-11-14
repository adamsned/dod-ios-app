import AppIntents
import DODSupport
import SwiftUI
import WidgetKit

// DUT-989 — Control Center / Lock Screen quick-start. One button reading
// "Cook: <dish>" or "Continue: Step N of <dish>"; tapping runs
// OpenTonightsRungIntent (Shared/CookingToolIntents.swift). iOS 18+ only.
// RUNTIME CHECK REQUIRED: not unit-testable; verify on an iOS 18+ sim/device.
@available(iOS 18.0, *)
struct TonightsRungControl: ControlWidget {
    static let kind = "com.dutchovendaddy.DODApp.Widget.TonightsRungControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind, provider: Provider()) { value in
            ControlWidgetButton(action: OpenTonightsRungIntent()) {
                Label(value.label, systemImage: "flame.fill")
            }
        }
        .displayName("Tonight's Rung")
        .description("Start cooking tonight's next dish in one tap.")
    }

    struct Value: Sendable {
        let label: String
    }

    struct Provider: ControlValueProvider {
        var previewValue: Value { Value(label: "Cook: Tonight's Dish") }

        func currentValue() async throws -> Value {
            let snapshot = WidgetSnapshotStore()?.readTonightsRung()
            return Value(label: snapshot?.label ?? "Cook Mode")
        }
    }
}

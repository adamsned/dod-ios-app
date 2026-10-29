import DODSupport
import SwiftUI

/// DUT-982 — short intake: Dutch oven (+ size), indoor/outdoor, experience.
public struct FirstCookQuizView: View {
    @State private var hasDutchOven = true
    @State private var ovenSize = 12
    @State private var setup: CookerIntake.Setup = .both
    @State private var experience: CookerIntake.Experience = .none
    let onDone: (CookerIntake) -> Void

    public init(onDone: @escaping (CookerIntake) -> Void) { self.onDone = onDone }

    /// Pure builder, so it is unit-testable without a view host.
    static func makeIntake(
        hasDutchOven: Bool,
        ovenSize: Int,
        setup: CookerIntake.Setup,
        experience: CookerIntake.Experience
    ) -> CookerIntake {
        CookerIntake(
            hasDutchOven: hasDutchOven,
            ovenSizeInches: hasDutchOven ? ovenSize : nil,
            setup: setup,
            experience: experience
        )
    }

    public var body: some View {
        Form {
            Toggle("I have a Dutch oven", isOn: $hasDutchOven)
            if hasDutchOven {
                Picker("Size", selection: $ovenSize) {
                    ForEach([8, 10, 12, 14], id: \.self) { Text("\($0) inch").tag($0) }
                }
            }
            Picker("Where will you cook?", selection: $setup) {
                Text("Indoors").tag(CookerIntake.Setup.indoor)
                Text("Outdoors").tag(CookerIntake.Setup.outdoor)
                Text("Both").tag(CookerIntake.Setup.both)
            }
            Picker("Cooking experience", selection: $experience) {
                Text("New to it").tag(CookerIntake.Experience.none)
                Text("Some").tag(CookerIntake.Experience.some)
                Text("A lot").tag(CookerIntake.Experience.lots)
            }
            Button("Find my first cook") {
                onDone(
                    Self.makeIntake(
                        hasDutchOven: hasDutchOven,
                        ovenSize: ovenSize,
                        setup: setup,
                        experience: experience
                    )
                )
            }
        }
    }
}

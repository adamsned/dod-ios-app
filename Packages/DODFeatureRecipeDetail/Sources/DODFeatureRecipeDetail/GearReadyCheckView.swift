import DODDesignSystem
import DODDomain
import SwiftUI

/// DUT-984 — pre-Cook-Mode gear checklist. "Start Cooking" is always enabled
/// (a gate, not a wall); missing items show a substitution tip.
struct GearReadyCheckView: View {
    @State private var check: GearReadyCheck
    let onStart: () -> Void
    let onCancel: () -> Void

    init(equipment: [Equipment], onStart: @escaping () -> Void, onCancel: @escaping () -> Void) {
        _check = State(initialValue: GearReadyCheck(items: equipment))
        self.onStart = onStart
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(check.items) { item in
                        VStack(alignment: .leading, spacing: DODSpacing.xs) {
                            Button {
                                check.toggle(item)
                            } label: {
                                HStack {
                                    Image(systemName: check.has(item) ? "checkmark.circle.fill" : "circle")
                                    Text(item.name)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(check.has(item) ? .isSelected : [])
                            if !check.has(item), let tip = GearReadyCheck.substitutionTip(for: item.name) {
                                Text(tip).dodFont(DODType.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("\(check.haveCount) of \(check.items.count) ready")
                }
            }
            .navigationTitle("Gear Check")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) { Button("Start Cooking", action: onStart) }
            }
        }
    }
}

import DODDesignSystem
import DODSupport
import SwiftUI

/// The dump-cake option (DUT-190): the cook picks any blog dump cake, then runs
/// the same coached flow for it. One sheet — the picker first, then the chosen
/// cake's `FirstCookoutView` (built from the generic `GuidedCookout.dumpCake`
/// template). Dump cakes are all one method, so one flow covers the collection.
struct DumpCakeFlow: View {

    let onLogCook: (CookLogEntry) -> Void
    @State private var selected: DumpCake?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if let selected {
            FirstCookoutView(cookout: .dumpCake(selected), onLogCook: onLogCook)
        } else {
            picker
        }
    }

    private var picker: some View {
        NavigationStack {
            List(DumpCake.all) { cake in
                Button {
                    selected = cake
                } label: {
                    HStack(spacing: DODSpacing.sm) {
                        Image(systemName: "birthday.cake.fill")
                            .foregroundStyle(DODColor.burntOrange)
                        Text(cake.title)
                            .dodFont(DODType.body)
                            .foregroundStyle(DODColor.label)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(DODColor.labelSecondary)
                    }
                }
                .listRowBackground(DODColor.surfaceElevated)
                .accessibilityIdentifier("dump-cake-\(cake.id)")
            }
            .scrollContentBackground(.hidden)
            .background(DODColor.surface)
            .navigationTitle("Pick a Dump Cake")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(DODColor.burntOrange)
                }
            }
        }
    }
}

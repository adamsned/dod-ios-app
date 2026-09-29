import DODDesignSystem
import Foundation
import SwiftUI

// DUT-162 — the "Export My Data" Settings row + its share-sheet plumbing, split
// out of `SettingsView.swift` to keep that host file under the SwiftLint
// 400-line `file_length` cap. The row builds a single portable JSON file
// (saved recipes, cooking journal, shopping list, profile) and hands it to the
// system share sheet (Save to Files, AirDrop, Mail). Works fully offline and
// for guest users; the underlying gather runs off-device-store actors.
extension SettingsView {

    /// The "Export My Data" row, hosted in the Data & Privacy section.
    @ViewBuilder
    var exportDataRow: some View {
        Button {
            Task { await runExport() }
        } label: {
            Text("Export My Data")
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.accent)
        }
        // Block a second tap while a file is being built (mirrors the Clear
        // Cache row's in-flight guard) so overlapping exports can't race.
        .disabled(isExporting)
        .accessibilityIdentifier("settings-button-export-data")
    }

    /// Build the export file, then present the share sheet on success. A failed
    /// gather surfaces the view-model's snackbar rather than a silent no-op.
    func runExport() async {
        guard !isExporting else { return }
        isExporting = true
        defer { isExporting = false }
        if let url = await viewModel.exportMyData() {
            exportItem = ExportShareItem(fileURL: url)
        }
    }
}

/// Foundation-only Identifiable box driving the export `.sheet(item:)` — the
/// generated JSON file's local URL. Foundation-only (no UIKit) so the view
/// state compiles on the macOS `swift test` slice; the sheet itself is iOS-only.
struct ExportShareItem: Identifiable {
    let id = UUID()
    let fileURL: URL
}

#if os(iOS) && canImport(UIKit)
import UIKit

/// Thin SwiftUI wrapper over `UIActivityViewController` — the full iOS share
/// sheet (Save to Files, AirDrop, Mail, Messages). Mirrors the Recipe-Detail
/// `ShareSheet` (DUT-1324); a `ShareLink` can't be used because the file is
/// built at tap time, not upfront.
struct ExportShareSheet: UIViewControllerRepresentable {

    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
#endif

extension View {

    /// Attach the "Export My Data" share sheet. iOS-only; a no-op on the macOS
    /// `swift test` slice where `UIActivityViewController` is unavailable.
    @ViewBuilder
    func exportDataShareSheet(_ item: Binding<ExportShareItem?>) -> some View {
        #if os(iOS) && canImport(UIKit)
        sheet(item: item) { ExportShareSheet(items: [$0.fileURL]) }
        #else
        self
        #endif
    }
}

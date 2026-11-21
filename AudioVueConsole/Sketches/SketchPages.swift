import SwiftUI

/// The settings-style pages still on sample values, as grouped forms. Every value is made up.
struct SketchDisplayPage: View {
    let panel: SketchPanel
    @State private var saver = "Bounce"
    @State private var sleeps = true

    var body: some View {
        Form {
            Section("Screen") {
                LabeledContent("Size", value: "\(panel.widthPx) × \(panel.heightPx)")
            }
            Section("When idle") {
                Picker("Screen saver", selection: $saver) {
                    Text("Bounce").tag("Bounce")
                    Text("Off").tag("Off")
                }
                Toggle("Sleep when quiet", isOn: $sleeps)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Display")
    }
}

struct SketchLaterPage: View {
    let section: PanelSection

    var body: some View {
        ContentUnavailableView(
            section.title, systemImage: section.symbol,
            description: Text("Not sketched yet."))
    }
}

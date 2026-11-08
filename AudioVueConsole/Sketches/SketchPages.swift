import SwiftUI

/// The settings-style pages still on sample values, as grouped forms. Every value is made up.
struct SketchInputPage: View {
    @State private var device = "m2x4HD"
    @State private var pair = "Inputs 1–2"

    var body: some View {
        Form {
            Section {
                Picker("Device", selection: $device) {
                    Text("m2x4HD").tag("m2x4HD")
                    Text("CODEC").tag("CODEC")
                }
                Picker("Pair", selection: $pair) {
                    Text("Inputs 1–2").tag("Inputs 1–2")
                    Text("Inputs 3–4").tag("Inputs 3–4")
                }
            } footer: {
                SketchChainWarning()
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Input")
    }
}

struct SketchDisplayPage: View {
    let panel: SketchPanel
    @State private var saver = "Bounce"
    @State private var sleeps = true

    var body: some View {
        Form {
            Section("Screen") {
                LabeledContent("Size", value: "\(panel.widthPx) × \(panel.heightPx)")
                LabeledContent("Shape", value: panel.shapeName)
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

/// How a chain setting says that calibration no longer applies.
struct SketchChainWarning: View {
    var body: some View {
        Label(
            "Changing the input changes which audio is measured. Calibration no longer applies "
                + "until you calibrate again.",
            systemImage: "exclamationmark.triangle.fill"
        )
        .foregroundStyle(.orange)
    }
}

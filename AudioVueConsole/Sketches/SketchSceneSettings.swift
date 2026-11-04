import SwiftUI

/// The scene's own settings, shown in the inspector whenever no card is selected: what applies to
/// the whole scene rather than to one card. The values are made up; the host's settings schema will
/// declare them.
struct SketchSceneSettings: View {
    let scene: SketchScene
    @State private var fill = "Gradient"
    @State private var blur = SketchMetrics.defaultBlur
    @State private var glass = SketchMetrics.defaultGlassOpacity
    @State private var weighting = "F"

    var body: some View {
        Form {
            Section(scene.name) {
                LabeledContent("Grid") { Text(verbatim: "\(scene.cols) × \(scene.rows) cells") }
                Text("Set by the panel's shape").font(.caption).foregroundStyle(.secondary)
            }
            Section("Backdrop") {
                Picker("Fill", selection: $fill) {
                    ForEach(["Colour", "Gradient", "Image"], id: \.self) { Text($0) }
                }
                Slider(value: $blur, in: SketchMetrics.blurRange) { Text("Blur") }
            }
            Section("Plates") {
                Slider(value: $glass, in: SketchMetrics.unitRange) { Text("Glass") }
            }
            Section("Analysis") {
                Picker("RTA weighting", selection: $weighting) {
                    Text("Fast").tag("F")
                    Text("Slow").tag("S")
                    Text("Impulse").tag("I")
                }
            }
        }
        .formStyle(.grouped)
    }
}

#Preview("Scene settings") {
    if let scene = SketchData.shared.scenes.first {
        SketchSceneSettings(scene: scene)
    }
}

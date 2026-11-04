import SwiftUI

/// Editing one scene: the card library on the left, the canvas inside the panel's outline, and the
/// inspector on the right, which shows the scene's settings whenever no card is selected.
struct SketchSceneEditor: View {
    let panel: SketchPanel
    let scene: SketchScene
    let roster: [SketchCardKind]
    @State private var cardID: String?
    @State private var showsInspector = true

    var body: some View {
        HSplitView {
            SketchCardLibrary(kinds: roster)
                .frame(
                    minWidth: SketchMetrics.libraryMinWidth,
                    idealWidth: SketchMetrics.libraryIdealWidth,
                    maxWidth: SketchMetrics.libraryMaxWidth)
            SketchCanvas(panel: panel, scene: scene, cardID: $cardID)
                .frame(minWidth: SketchMetrics.canvasMinWidth)
        }
        .inspector(isPresented: $showsInspector) {
            SketchInspector(card: card, scene: scene)
                .inspectorColumnWidth(
                    min: SketchMetrics.inspectorMinWidth, ideal: SketchMetrics.inspectorIdealWidth,
                    max: SketchMetrics.inspectorMaxWidth)
        }
        .toolbar { toolbar }
        .navigationTitle(scene.name)
        .navigationSubtitle(panel.name)
    }

    private var card: SketchCard? { scene.cards.first { $0.id == cardID } }
    private var fits: Bool { panel.fits(scene) }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItemGroup {
            Button(
                fits ? "Duplicate" : "Duplicate for This Panel",
                systemImage: "plus.square.on.square"
            ) {}
            Button("Show on Panel", systemImage: "play.fill") {}
                .disabled(!fits)
            Button("Inspector", systemImage: "sidebar.trailing") { showsInspector.toggle() }
        }
    }
}

/// The selected card's settings, or the scene's when no card is selected.
struct SketchInspector: View {
    let card: SketchCard?
    let scene: SketchScene

    var body: some View {
        if let card {
            Form {
                Section(card.title) {
                    LabeledContent("Position", value: "column \(card.col), row \(card.row)")
                    LabeledContent("Size", value: "\(card.colspan) × \(card.rowspan) cells")
                    LabeledContent("Group", value: card.group ?? "None")
                }
                Section("Settings") {
                    Text(
                        "Generated from the host's settings schema: each setting's label, "
                            + "unit, range and help."
                    )
                    .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
        } else {
            SketchSceneSettings(scene: scene)
        }
    }
}

#Preview("Scene editor") {
    let data = SketchData.shared
    if let panel = data.panels.first,
        let scene = data.scenes.first(where: { $0.spec == "glass-check" })
    {
        SketchSceneEditor(
            panel: panel, scene: scene, roster: SketchCardKind.roster(from: data.scenes)
        )
        .frame(
            width: SketchMetrics.windowDefaultWidth,
            height: SketchMetrics.windowDefaultHeight)
    }
}

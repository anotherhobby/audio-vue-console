import ConsoleCore
import SwiftUI

/// Editing one scene: the card library on the left, the scene canvas inside the panel's outline,
/// and the inspector on the right, which shows the scene's settings whenever no card is selected.
struct SketchSceneEditor: View {
    let panel: SketchPanel
    let scene: SketchScene
    let roster: [SketchCardKind]
    @Environment(SceneStore.self) private var store
    @Environment(\.undoManager) private var undoManager
    @State private var editor: SceneEditor?
    @State private var showsInspector = true

    var body: some View {
        HSplitView {
            SketchCardLibrary(kinds: roster)
                .frame(
                    minWidth: SketchMetrics.libraryMinWidth,
                    idealWidth: SketchMetrics.libraryIdealWidth,
                    maxWidth: SketchMetrics.libraryMaxWidth)
            canvas
                .frame(minWidth: SketchMetrics.canvasMinWidth)
        }
        .inspector(isPresented: $showsInspector) {
            SketchInspector(editor: editor, scene: scene)
                .inspectorColumnWidth(
                    min: SketchMetrics.inspectorMinWidth, ideal: SketchMetrics.inspectorIdealWidth,
                    max: SketchMetrics.inspectorMaxWidth)
        }
        .toolbar { toolbar }
        .navigationTitle(scene.name)
        .navigationSubtitle(panel.name)
        .onAppear { editor = makeEditor() }
        .onDisappear { editor?.detach() }
    }

    @ViewBuilder private var canvas: some View {
        if let editor {
            SceneCanvas(editor: editor, panelAspect: panel.aspect, sizeOf: size(of:))
        } else {
            ContentUnavailableView("No Scene", systemImage: "rectangle.3.group")
        }
    }

    private var fits: Bool { panel.fits(scene) }

    /// Built-in scenes are read-only, and so is a scene of another shape than the panel's.
    private var readOnly: ReadOnlyReason? {
        if scene.builtIn { return .builtIn }
        return fits ? nil : .shape(scene: scene.shapeName, panel: panel.shapeName)
    }

    private func makeEditor() -> SceneEditor? {
        guard let layout = store.layout(for: scene) else { return nil }
        return SceneEditor(layout: layout, readOnly: readOnly, undoManager: undoManager) {
            [store, scene] in store.keep($0, for: scene)
        }
    }

    private func size(of kind: String) -> CellSize? {
        roster.first { $0.card == kind }.map { CellSize(cols: $0.cols, rows: $0.rows) }
    }

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

/// The selected card's place on the grid, the selection's Group and Ungroup with the reason Group
/// is refused, or the scene's settings when nothing is selected.
struct SketchInspector: View {
    let editor: SceneEditor?
    let scene: SketchScene

    var body: some View {
        let cards = editor?.selectedCards ?? []
        if let editor, let card = cards.first, cards.count == 1 {
            single(card, editor)
        } else if let editor, !cards.isEmpty {
            several(cards, editor)
        } else {
            SketchSceneSettings(scene: scene)
        }
    }

    private func single(_ card: LayoutCard, _ editor: SceneEditor) -> some View {
        Form {
            Section(card.kind.replacingOccurrences(of: "_", with: " ")) {
                LabeledContent("Position") {
                    Text(verbatim: "column \(card.cells.col), row \(card.cells.row)")
                }
                LabeledContent("Size") {
                    Text(verbatim: "\(card.cells.cols) × \(card.cells.rows) cells")
                }
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
    }

    private func several(_ cards: [LayoutCard], _ editor: SceneEditor) -> some View {
        Form {
            Section {
                LabeledContent("Selected") { Text(verbatim: "\(cards.count) cards") }
                HStack {
                    Button("Group") { editor.group() }
                        .disabled(editor.groupRefusal != nil)
                    Button("Ungroup") { editor.ungroup() }
                        .disabled(!editor.canUngroup)
                }
                if let refusal = editor.groupRefusal {
                    Text(refusal.description).font(.callout).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}

#Preview("Scene editor") {
    let data = SketchData.shared
    if let panel = data.panels.first,
        let scene = data.scenes.first(where: { $0.spec == "workbench" })
    {
        SketchSceneEditor(
            panel: panel, scene: scene, roster: SketchCardKind.roster(from: data.scenes)
        )
        .environment(SceneStore())
        .frame(
            width: SketchMetrics.windowDefaultWidth,
            height: SketchMetrics.windowDefaultHeight)
    }
}

/// The canvas and inspector with cards already selected, which a live editor only gets by clicks.
private struct SelectedPreview: View {
    private let store = SceneStore()
    private let panel = SketchData.shared.panels.first
    private let scene = SketchData.shared.scenes.first { $0.spec == "workbench" }
    private let editor: SceneEditor?

    init(kinds: [String]) {
        guard let scene, let layout = store.layout(for: scene) else {
            editor = nil
            return
        }
        let editor = SceneEditor(layout: layout)
        for card in layout.cards where kinds.contains(card.kind) { editor.toggle(card.id) }
        self.editor = editor
    }

    var body: some View {
        if let editor, let panel, let scene {
            HStack(spacing: 0) {
                SceneCanvas(editor: editor, panelAspect: panel.aspect) { _ in nil }
                SketchInspector(editor: editor, scene: scene)
                    .frame(width: SketchMetrics.inspectorIdealWidth)
            }
            .environment(store)
            .frame(
                width: SketchMetrics.windowDefaultWidth, height: SketchMetrics.windowDefaultHeight)
        }
    }
}

#Preview("One card selected") {
    SelectedPreview(kinds: ["goniometer"])
}

#Preview("Two cards selected") {
    SelectedPreview(kinds: ["waveform", "peak_rms"])
}

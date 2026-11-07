import ConsoleCore
import SwiftUI

/// One scene open for editing: the card library on the left, the canvas inside the panel's outline
/// drawn by the helper, and the inspector on the right (`scene-canvas`, `scene-rendering`). Edits
/// are kept in the app until it quits and never written to the host.
struct SceneEditorView: View {
    let document: SceneDocument
    let scenes: PanelScenes
    let renderer: Renderer
    let verdict: CardCodeVerdict?
    let panel: DisplayShape
    /// Opens a scene by id, as Duplicate does with its copy.
    let open: (String) -> Void
    @Environment(SceneStore.self) private var store
    @Environment(\.undoManager) private var undoManager
    @State private var editor: SceneEditor?
    @State private var rendering: SceneRendering?
    @State private var showsInspector = true

    var body: some View {
        HSplitView {
            CardLibrary(cards: scenes.facts?.placeable ?? [], sizeOf: { editor?.minimums[$0] })
                .frame(
                    minWidth: SceneMetrics.libraryMinWidth,
                    idealWidth: SceneMetrics.libraryIdealWidth,
                    maxWidth: SceneMetrics.libraryMaxWidth)
            canvas.frame(minWidth: SceneMetrics.canvasMinWidth)
        }
        .inspector(isPresented: $showsInspector) {
            SceneInspector(editor: editor, document: document)
                .inspectorColumnWidth(
                    min: SceneMetrics.inspectorMinWidth, ideal: SceneMetrics.inspectorIdealWidth,
                    max: SceneMetrics.inspectorMaxWidth)
        }
        .toolbar { toolbar }
        .navigationTitle(document.name ?? document.id)
        .onAppear(perform: make)
        .onDisappear { editor?.detach() }
        .task(id: renderer.phase) { await follow(renderer.phase) }
        .onChange(of: verdict) { _, verdict in verdict.map { rendering?.apply($0) } }
        .onChange(of: rendering?.status) { _, status in
            if status == .drawn, let rendering {
                store.thumbnails.update(document.id, from: rendering)
            }
        }
    }

    @ViewBuilder private var canvas: some View {
        if let editor {
            SceneCanvas(
                editor: editor, panelAspect: panel.aspect, sizeOf: { editor.minimums[$0] },
                rendering: rendering)
        } else {
            ContentUnavailableView("This Scene Can't Be Read", systemImage: "rectangle.3.group")
        }
    }

    /// The editor over the scene as last edited, and the layers that follow it.
    private func make() {
        guard editor == nil, let facts = scenes.facts,
            let laidOut = ScenesPage.laidOut(document, facts: facts)
        else { return }
        let grid = laidOut.layout.grid
        let scene = DisplayShape(width: grid.cols, height: grid.rows)
        let readOnly: ReadOnlyReason? =
            document.builtIn
            ? .builtIn
            : panel.matches(scene)
                ? nil : .shape(scene: scene.description, panel: panel.description)
        editor = SceneEditor(
            layout: store.drafts.layout(for: document.id) ?? laidOut.layout, readOnly: readOnly,
            minimums: facts.minimums(forRows: grid.rows), undoManager: undoManager
        ) { [store, document] in store.drafts.keep($0, for: document.id) }
        let rendering = SceneRendering(
            scene: laidOut, context: scenes.context, displayKnown: scenes.display != nil)
        if let verdict { rendering.apply(verdict) }
        self.rendering = rendering
    }

    /// Draws once the renderer is ready, and says why not where it failed.
    private func follow(_ phase: Renderer.Phase) async {
        guard let rendering, let editor else { return }
        await rendering.show(editor.layout)
        switch phase {
        case .ready: if let queue = renderer.queue { await rendering.attach(queue) }
        case .failed(let reason): rendering.unavailable(reason)
        case .idle, .starting, .preparing: break
        }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItemGroup {
            Button("Duplicate", systemImage: "plus.square.on.square") { duplicate() }
                .disabled(
                    editor?.readOnly.map { if case .shape = $0 { true } else { false } } ?? false)
            Button("Inspector", systemImage: "sidebar.trailing") { showsInspector.toggle() }
        }
    }

    private func duplicate() {
        guard let facts = scenes.facts, let laidOut = ScenesPage.laidOut(document, facts: facts)
        else { return }
        open(store.drafts.duplicate(laidOut).id)
    }
}

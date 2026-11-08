import ConsoleCore
import SwiftUI

/// One scene open for editing: the card library on the left, the canvas inside the panel's outline
/// drawn by the helper, and the inspector on the right (`scene-canvas`, `scene-rendering`). Edits
/// are kept in the scene's draft until saved or discarded (`scene-saving`).
struct SceneEditorView: View {
    let document: SceneDocument
    let scenes: PanelScenes
    let renderer: Renderer
    let verdict: CardCodeVerdict?
    let panel: DisplayShape
    /// The panel's live state, which says the scene on screen.
    let live: LiveState?
    /// Opens a scene by id, as Duplicate does with its copy.
    let open: (String) -> Void
    /// Shows the scene by id in place of this one, as a copy's first save does.
    let reopen: (String) -> Void
    @Environment(SceneStore.self) private var store
    @Environment(\.undoManager) private var undoManager
    @State private var editor: SceneEditor?
    @State private var rendering: SceneRendering?
    @State private var showsInspector = true
    /// The scene's writes, made with the editor.
    @State private var session: SceneSession?
    /// Counts the renderings made, so the drawing follows a new one.
    @State private var made = 0

    var body: some View {
        panes
            .safeAreaInset(edge: .top, spacing: 0) {
                if let banner { EditorBanner(text: banner) }
            }
            .toolbar { toolbar }
            .navigationTitle(document.name ?? document.id)
            .toolbar(removing: .title)
            .focusedSceneValue(\.sceneFile, fileActions)
            .writeFailureAlert(failure, saveOver: { save(overRev: $0) }, discardMine: discardMine)
            .onAppear(perform: make)
            .onChange(of: session?.parses) { drawNewParse() }
            .onChange(of: editor?.layout) { session?.note = nil }
            .onDisappear { editor?.detach() }
            .task(id: Drawing(phase: renderer.phase, made: made)) { await follow(renderer.phase) }
            .onChange(of: verdict) { _, verdict in
                verdict.map { rendering?.apply($0) }
                if case .ready = renderer.phase { Task { await drawTiles() } }
            }
            .onChange(of: rendering?.status) { _, status in
                if status == .drawn, let rendering {
                    store.thumbnails.update(document.id, from: rendering)
                    rendering.backdrop.map { store.tiles.show(backdrop: $0) }
                }
            }
    }

    /// The card library, the canvas and the inspector.
    private var panes: some View {
        HSplitView {
            library
            canvas.frame(minWidth: SceneMetrics.canvasMinWidth)
        }
        .inspector(isPresented: $showsInspector) {
            SceneInspector(editor: editor, document: document)
                .inspectorColumnWidth(
                    min: SceneMetrics.inspectorMinWidth, ideal: SceneMetrics.inspectorIdealWidth,
                    max: SceneMetrics.inspectorMaxWidth)
        }
    }

    private var library: some View {
        CardLibrary(
            cards: scenes.facts?.placeable ?? [], tiles: store.tiles.tiles,
            sizeOf: { editor?.minimums[$0] }
        )
        .frame(
            minWidth: SceneMetrics.libraryMinWidth, idealWidth: SceneMetrics.libraryIdealWidth,
            maxWidth: SceneMetrics.libraryMaxWidth)
    }

    @ViewBuilder private var canvas: some View {
        if let editor {
            SceneCanvas(
                editor: editor, panelAspect: panel.aspect, sizeOf: { editor.minimums[$0] },
                rendering: rendering,
                title: SceneNameTitle(
                    name: document.name ?? document.id, isUnsaved: session?.isUnsaved == true,
                    rename: renaming))
        } else {
            ContentUnavailableView("This Scene Can't Be Read", systemImage: "rectangle.3.group")
        }
    }

    /// The editor over the scene's draft, and the layers that follow it, both from the draft's own
    /// parse so every card keeps its entry (design D1).
    private func make() {
        guard editor == nil, let facts = scenes.facts,
            let draft = ScenesPage.draft(document, in: store.drafts, facts: facts)
        else { return }
        let grid = draft.layout.grid
        let scene = DisplayShape(width: grid.cols, height: grid.rows)
        let readOnly: ReadOnlyReason? =
            document.builtIn
            ? .builtIn
            : panel.matches(scene)
                ? nil : .shape(scene: scene.description, panel: panel.description)
        let editor = SceneEditor(
            layout: draft.layout, readOnly: readOnly,
            minimums: facts.minimums(forRows: grid.rows), undoManager: undoManager
        ) { [store, document] in store.drafts.keep($0, for: document.id) }
        let session = SceneSession(id: document.id, writes: store.writes(to: scenes))
        session.attach(editor)
        session.note = store.takeNote(for: document.id)
        self.editor = editor
        self.session = session
        draw(draft)
    }

    /// The layers of `draft`'s parse, drawn afresh.
    private func draw(_ draft: Draft) {
        let rendering = SceneRendering(
            scene: draft.laidOut, context: scenes.context, displayKnown: scenes.display != nil)
        if let verdict { rendering.apply(verdict) }
        self.rendering = rendering
        made += 1
    }

    /// Draws the draft's new parse, after a version was loaded or the host's scene read again.
    private func drawNewParse() {
        if let draft = session?.draft { draw(draft) }
    }

    /// Draws once the renderer is ready, and says why not where it failed.
    private func follow(_ phase: Renderer.Phase) async {
        guard let rendering, let editor else { return }
        await rendering.show(editor.layout)
        switch phase {
        case .ready:
            if let queue = renderer.queue {
                await rendering.attach(queue)
                await drawTiles()
            }
        case .failed(let reason): rendering.unavailable(reason)
        case .idle, .starting, .preparing: break
        }
    }

    /// Draws the library's tiles in this scene's settings once the canvas has asked for its own
    /// drawing, where the panel's code lets cards be drawn, as the gallery's thumbnails are
    /// (`library-render` design D4). Where no card can be drawn, the tiles are boxes.
    private func drawTiles() async {
        guard let rendering, let queue = renderer.queue, let cards = scenes.facts?.placeable
        else { return }
        let drift: CardDrift?
        switch verdict {
        case .same?: drift = nil
        case .differs(let differs)? where !differs.sharesNothing: drift = differs
        case nil: return
        default:
            store.tiles.forget()
            return
        }
        await store.tiles.draw(
            for: rendering.scene, cards: cards, drift: drift, context: scenes.context,
            through: queue)
    }

    /// The scene's tools in the middle of the toolbar, Reset set apart after them, as it acts on the
    /// panel's measurement and not the scene, and the inspector's toggle at the end.
    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .principal) {
            Button("Save", systemImage: "square.and.arrow.down") { save() }
                .disabled(session?.canSave != true)
            Button("Revert", systemImage: "arrow.uturn.backward") { session?.revert() }
                .disabled(session?.canRevert != true)
            if let session {
                VersionsMenu(session: session)
            }
            Button("Apply", systemImage: "play.rectangle") { apply() }
                .disabled(editor == nil || isOtherShape)
                .help(isOtherShape ? "This scene is shaped for another panel." : "")
            Button("Duplicate", systemImage: "plus.square.on.square") { duplicate() }
                .disabled(isOtherShape)
        }
        ToolbarItem(placement: .principal) {
            Color.clear.frame(width: SceneMetrics.toolbarGap)
        }
        .sharedBackgroundVisibility(.hidden)
        ToolbarItem(placement: .principal) {
            Button("Reset", systemImage: "arrow.counterclockwise") {
                Task { await session?.reset() }
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Button("Inspector", systemImage: "sidebar.trailing") { showsInspector.toggle() }
        }
    }

    private func duplicate() {
        guard let facts = scenes.facts,
            let draft = ScenesPage.draft(document, in: store.drafts, facts: facts)
        else { return }
        open(store.drafts.duplicate(draft, among: scenes.scenes).id)
    }

    /// Whether the scene is shaped for another panel, so it is neither duplicated nor applied here.
    private var isOtherShape: Bool {
        editor?.readOnly.map { if case .shape = $0 { true } else { false } } ?? false
    }

    /// The banner's line: the last Apply's or Reset's outcome, else the panel-behind note.
    private var banner: String? {
        if let note = session?.note { return EditorBannerText.text(note) }
        return store.behind.contains(document.id) ? EditorBannerText.behind : nil
    }

    /// What the File menu may do to this scene.
    private var fileActions: SceneFileActions {
        SceneFileActions(
            save: session?.canSave == true ? { save() } : nil,
            revert: session?.canRevert == true ? { session?.revert() } : nil)
    }

    /// The name's rename, nil for a built-in, which is never renamed.
    private var renaming: ((String) async -> Void)? {
        guard !document.builtIn, let session else { return nil }
        return { name in await session.rename(name) }
    }

    /// The session's failure, for the alert to show and clear.
    private var failure: Binding<HostFailure?> {
        Binding(get: { session?.failure }, set: { session?.failure = $0 })
    }

    /// Saves the draft, on `overRev` where the user chose Save Over It. A copy's first save shows
    /// the scene under the host's id.
    private func save(overRev: Int? = nil) {
        Task {
            guard let stored = await session?.save(overRev: overRev) else { return }
            store.saved(stored.id, onScreen: live?.state?.sceneSpec)
            if stored.id != document.id { reopen(stored.id) }
        }
    }

    /// Apply: saves where unsaved, then puts the scene on the panel. A copy's first save shows the
    /// scene under the host's id, its outcome handed to the editor that opens on it.
    private func apply() {
        Task {
            guard let session, let id = await session.apply() else { return }
            if case .success(.done) = session.note?.result { store.applied(id) }
            if id != document.id {
                store.hand(session.note, to: id)
                reopen(id)
            }
        }
    }

    private func discardMine() {
        Task { await session?.discardMine() }
    }

    /// What the drawing follows: the renderer's phase, and each new rendering.
    private struct Drawing: Equatable {
        let phase: Renderer.Phase
        let made: Int
    }
}

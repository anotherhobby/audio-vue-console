import ConsoleCore
import SwiftUI

/// The Scenes page (`scene-gallery`): the paired panel's scenes in a gallery, this panel's shape
/// first, each opened on the canvas. It reads the scenes when the app pairs, and draws the
/// thumbnails once the renderer has compared the card code. `isEditing` tells the window to give
/// the editor the width.
struct ScenesPage: View {
    let connection: HostConnection
    let renderer: Renderer
    /// The panel's live state, for the editor's panel-behind note.
    let live: LiveState?
    @Binding var isEditing: Bool
    @Environment(SceneStore.self) private var store
    @State private var scenes: PanelScenes?
    @State private var path: [String] = []

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle("Scenes")
                .navigationDestination(for: String.self) { destination($0) }
        }
        .onChange(of: path) { isEditing = !path.isEmpty }
        .task(id: PanelKey(connection)) { await load() }
        .task(id: DrawKey(verdict: renderer.verdict, loaded: scenes?.state == .loaded)) {
            await drawThumbnails()
        }
    }

    @ViewBuilder private var content: some View {
        if connection.isPaired != true || scenes?.state == .unpaired {
            ContentUnavailableView(
                "No Panel Paired", systemImage: "rectangle.3.group",
                description: Text("Pair with the panel on the Panel page to see its scenes."))
        } else if let scenes, scenes.state == .loaded, let facts = scenes.facts {
            SceneGallery(
                scenes: store.drafts.listing(scenes.scenes), facts: facts,
                panel: Self.shape(of: scenes), notice: renderer.verdict?.noCardsReason,
                open: { path.append($0) },
                rename: { id, name throws(HostFailure) in
                    try await store.writes(to: scenes).rename(id, to: name)
                },
                delete: { id throws(HostFailure) in
                    path.removeAll { $0 == id }
                    try await store.writes(to: scenes).delete(id)
                })
        } else if case .failed(let failure)? = scenes?.state {
            ContentUnavailableView(
                "Can't Read the Panel's Scenes", systemImage: "exclamationmark.triangle",
                description: Text(verbatim: "The host answered: \(failure).")
            )
        } else {
            ProgressView("Reading the panel's scenes…")
        }
    }

    @ViewBuilder private func destination(_ id: String) -> some View {
        if let scenes,
            let document = store.drafts.listing(scenes.scenes).first(where: { $0.id == id })
        {
            SceneEditorView(
                document: document, scenes: scenes, renderer: renderer, verdict: renderer.verdict,
                panel: Self.shape(of: scenes), live: live, open: { path.append($0) },
                reopen: { path[path.count - 1] = $0 })
        }
    }

    /// The panel's shape, from its display size, or the stand-in's where the host gives none.
    static func shape(of scenes: PanelScenes) -> DisplayShape {
        let display = scenes.context.display
        return DisplayShape(width: display.width, height: display.height)
    }

    /// Reads the scenes of the panel now paired, forgetting the last panel's edits and copies
    /// where it is another host.
    private func load() async {
        store.follow(host: connection.isPaired == true ? connection.host?.id : nil)
        path = []
        scenes = connection.makeScenes()
        store.scenes = scenes
        await scenes?.load()
    }

    /// Once the scenes are read and the renderer has compared the card code with the panel's (the
    /// window does, `PanelWindow`), draws the thumbnails, unless no card may be drawn.
    private func drawThumbnails() async {
        guard let scenes, scenes.state == .loaded, let facts = scenes.facts,
            let queue = renderer.queue
        else { return }
        switch renderer.verdict {
        case .same?: break
        case .differs(let drift)? where !drift.sharesNothing: break
        default: return
        }
        let laidOut = store.drafts.listing(scenes.scenes).compactMap { document in
            if let draft = store.drafts.draft(document.id) { return (draft.laidOut, draft.layout) }
            return Self.laidOut(document, facts: facts).map { ($0, $0.layout) }
        }
        await store.thumbnails.draw(laidOut, context: scenes.context, through: queue)
    }

    static func laidOut(_ document: SceneDocument, facts: SchemaFacts) -> LaidOutScene? {
        do {
            return try LaidOutScene(document, defaultGrid: facts.defaultGrid)
        } catch {
            return nil
        }
    }

    /// `document`'s draft, made the first time it is asked for, or nil where it cannot be read.
    static func draft(_ document: SceneDocument, in drafts: SceneDrafts, facts: SchemaFacts)
        -> Draft?
    {
        do {
            return try drafts.draft(for: document, defaultGrid: facts.defaultGrid)
        } catch {
            return nil
        }
    }

    /// The panel the page reads: a new address, or pairing again, reads its scenes again.
    private struct PanelKey: Hashable {
        let address: HostAddress?
        let paired: Bool?

        @MainActor init(_ connection: HostConnection) {
            address = connection.address
            paired = connection.isPaired
        }
    }

    private struct DrawKey: Equatable {
        let verdict: CardCodeVerdict?
        let loaded: Bool
    }
}

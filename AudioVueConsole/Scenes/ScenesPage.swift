import ConsoleCore
import SwiftUI

/// The Scenes page (`scene-gallery`): the paired panel's scenes in a gallery, the user's first,
/// then the built-ins, each opened on the canvas, laid out on the panel's grid. The window reads the scenes
/// when the app pairs and draws them ahead (`SceneStore.drawAhead`); the page reads them again
/// when shown. `isEditing`
/// tells the window to give the editor the width.
struct ScenesPage: View {
    let connection: HostConnection
    let renderer: Renderer
    /// The panel's live state, for the editor's panel-behind note.
    let live: LiveState?
    @Binding var isEditing: Bool
    @Environment(SceneStore.self) private var store
    /// The paired panel's scenes, read by the window as soon as it is paired.
    private var scenes: PanelScenes? { store.scenes }
    /// The panel's input, for the calibrated rates the editor warns by.
    @State private var input: PanelInput?
    @State private var path: [String] = []

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle("Scenes")
                .navigationDestination(for: String.self) { destination($0) }
        }
        .onChange(of: path) { isEditing = !path.isEmpty }
        // An open editor holds a layout on the old grid, so a new grid closes it.
        .onChange(of: store.grid) { path = [] }
        .task(id: PanelKey(connection)) { await load() }
        .task(id: drawKey) { await store.drawAhead(with: renderer) }
    }

    @ViewBuilder private var content: some View {
        if connection.isPaired != true || scenes?.state == .unpaired {
            ContentUnavailableView(
                "No Panel Paired", systemImage: "rectangle.3.group",
                description: Text("Pair with the panel on the Panel page to see its scenes."))
        } else if let scenes, scenes.state == .loaded, store.grid == nil {
            ContentUnavailableView(
                "No Display on the Panel", systemImage: "display.trianglebadge.exclamationmark",
                description: Text(
                    "The panel has no display to lay scenes out for. Its scenes show here once it does."
                ))
        } else if let scenes, scenes.state == .loaded, let grid = store.grid {
            SceneGallery(
                scenes: store.drafts.listing(scenes.scenes), grid: grid,
                aspect: Self.aspect(of: scenes), notice: renderer.verdict?.noCardsReason,
                shape: scenes.facts?.shape ?? .none,
                open: { path.append($0) },
                rename: { id, name throws(HostFailure) in
                    try await store.writes(to: scenes).rename(id, to: name)
                },
                delete: { id throws(HostFailure) in
                    path.removeAll { $0 == id }
                    try await store.writes(to: scenes).delete(id)
                },
                session: { SceneSession(id: $0, writes: store.writes(to: scenes)) },
                onScreen: live?.state?.sceneSpec)
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
        if let scenes, let grid = store.grid,
            let document = store.drafts.listing(scenes.scenes).first(where: { $0.id == id })
        {
            SceneEditorView(
                document: document, scenes: scenes, renderer: renderer, verdict: renderer.verdict,
                panel: grid, live: live, input: input,
                open: { path.append($0) },
                reopen: { path[path.count - 1] = $0 })
        }
    }

    /// The display's width over its height, or the stand-in's where the host gives no size.
    static func aspect(of scenes: PanelScenes) -> Double {
        let display = scenes.context.display
        return Double(display.width) / Double(display.height)
    }

    private var drawKey: DrawKey {
        DrawKey(
            verdict: renderer.verdict, loaded: scenes?.state == .loaded, grid: store.grid)
    }

    /// Shows the gallery of the panel now paired, and reads its scenes again where the window
    /// has already read them, so a change made elsewhere shows without the gallery leaving.
    private func load() async {
        path = []
        if scenes?.state == .loaded { await scenes?.load() }
        input = connection.makePanelInput()
        await input?.load()
    }

    /// `document` laid out on `grid`, the panel's, or nil where it cannot be read.
    static func laidOut(_ document: SceneDocument, on grid: CellSize) -> LaidOutScene? {
        do {
            return try LaidOutScene(document, panel: grid)
        } catch {
            return nil
        }
    }

    /// `document`'s draft, made the first time it is asked for, or nil where it cannot be read.
    static func draft(_ document: SceneDocument, in drafts: SceneDrafts, on grid: CellSize)
        -> Draft?
    {
        do {
            return try drafts.draft(for: document, panel: grid)
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
        let grid: CellSize?
    }
}

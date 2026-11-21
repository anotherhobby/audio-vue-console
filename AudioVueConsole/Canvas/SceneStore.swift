import ConsoleCore
import Observation

/// What the Scenes page keeps while the app runs, owned by the App so it outlives the window: each
/// scene's draft and the copies Duplicate made, until saved or discarded (`scene-saving`), the
/// gallery's thumbnails, and the card library's tiles.
@MainActor @Observable
final class SceneStore {
    let drafts = SceneDrafts()
    let thumbnails = SceneThumbnails()
    let tiles = LibraryTiles()
    /// The question asked before unsaved scenes would be lost.
    let unsaved = UnsavedScenes()
    /// The paired panel's scenes as the window read them once paired, which a save writes to.
    var scenes: PanelScenes?
    /// The grid the panel lays scenes out on, from its live state; nil until it says one, and
    /// while it has no display (`scene-layout`, "A scene is laid out on the panel's grid").
    private(set) var grid: CellSize?
    /// The card kind being dragged from the library, set as the drag starts, so the canvas can
    /// preview its size before the drop delivers it.
    var draggedKind: String?
    /// How many drops the canvas has taken. The library's tiles are made again after each: once a
    /// tile's drop is refused, SwiftUI never calls its `onDrag` again (measured, 2026-11-07).
    var drops = 0
    /// The scenes saved while on screen, which the panel shows at an earlier version until an
    /// Apply or another scene goes up (design D10). Held while the app runs.
    private(set) var behind: Set<String> = []
    /// An Apply's outcome handed to the editor that opens on the scene next, by its id.
    private var handed: (id: String, note: EditorNote)?
    /// The paired host the drafts belong to, by its id.
    private var hostID: String?

    /// Keeps the drafts while the paired host is the one they belong to, so a reconnect to the
    /// same panel keeps them, and forgets them once another host is paired (design D6). Nothing is
    /// forgotten while no host is paired.
    func follow(host id: String?) {
        guard let id, id != hostID else { return }
        forget()
        hostID = id
    }

    /// Follows the panel's grid: drafts are laid out again on a new one, what was drawn on the
    /// old one is dropped, and the thumbnails kept from the last launch are shown.
    func follow(grid: CellSize?) {
        guard grid != self.grid else { return }
        self.grid = grid
        guard let grid else { return }
        drafts.relay(on: grid)
        thumbnails.forget()
        tiles.forget()
        restoreThumbnails()
    }

    /// Notes a save of the scene `id`, behind on the panel where it is the one on screen.
    func saved(_ id: String, onScreen spec: String?) {
        if id == spec { behind.insert(id) }
    }

    /// Notes a done Apply of the scene `id`, which puts its current revision up.
    func applied(_ id: String) {
        behind.remove(id)
    }

    /// Hands `note` to the editor that opens on the scene `id` next, as after a copy's Apply.
    func hand(_ note: EditorNote?, to id: String) {
        handed = note.map { (id, $0) }
    }

    /// The note handed to the scene `id`'s editor, given once.
    func takeNote(for id: String) -> EditorNote? {
        guard let handed, handed.id == id else { return nil }
        self.handed = nil
        return handed.note
    }

    /// Follows the scene on screen: a note for any other scene is dropped.
    func follow(onScreen spec: String?) {
        behind = behind.filter { $0 == spec }
    }

    /// The writes to `scenes`' host, whose outcomes reach this store's drafts and thumbnails.
    func writes(to scenes: PanelScenes) -> SceneWrites {
        SceneWrites(scenes: scenes, drafts: drafts, thumbnails: thumbnails)
    }

    /// The writes to the panel the Scenes page read, or nil before it has read one.
    var currentWrites: SceneWrites? {
        scenes.map(writes(to:))
    }

    /// Draws every scene's thumbnail, then the library's tiles in each scene's settings, ahead of
    /// the Scenes page or a scene being opened, so both show at once (`scene-rendering`, "Scenes
    /// and tiles are drawn ahead"). Nothing is drawn until the scenes are read and the renderer
    /// has compared its card code with the panel's, or where no card may be drawn.
    func drawAhead(with renderer: Renderer) async {
        guard let scenes, scenes.state == .loaded, let facts = scenes.facts, let grid,
            let queue = renderer.queue
        else { return }
        let drift: CardDrift?
        switch renderer.verdict {
        case .same?: drift = nil
        case .differs(let differs)? where !differs.sharesNothing: drift = differs
        default: return
        }
        let listed = listed(scenes, on: grid)
        // A thumbnail is kept for the next launch only where it is drawn by the panel's code.
        await thumbnails.draw(
            listed.map { ($0.laidOut, $0.content) }, context: scenes.context, through: queue,
            keeping: drift == nil ? ThumbnailCache(digest: scenes.cards.digest) : nil)
        let source = LibraryTiles.Source(
            cards: facts.placeable, drift: drift, context: scenes.context, queue: queue)
        for draft in listed.prefix(LibraryTiles.kept) {
            await tiles.prepare(for: draft, from: source)
        }
    }

    /// Shows the thumbnails kept from the last launch for the scenes as they are now, as soon as
    /// the scenes are read and before the renderer is ready.
    func restoreThumbnails() {
        guard let scenes, scenes.state == .loaded, let grid else { return }
        thumbnails.restore(
            listed(scenes, on: grid).map { ($0.laidOut, $0.content) }, context: scenes.context,
            from: ThumbnailCache(digest: scenes.cards.digest))
    }

    /// Every scene listed, as edited where it has a draft and as read otherwise.
    private func listed(_ scenes: PanelScenes, on grid: CellSize) -> [Draft] {
        drafts.listing(scenes.scenes).compactMap { document in
            drafts.draft(document.id) ?? ScenesPage.laidOut(document, on: grid).map(Draft.init)
        }
    }

    /// Forgets the edits, copies, thumbnails and tiles, as when another panel is shown.
    func forget() {
        drafts.forget()
        thumbnails.forget()
        tiles.forget()
        grid = nil
    }
}

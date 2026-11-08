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
    /// The paired panel's scenes as the Scenes page last read them, which a save writes to.
    var scenes: PanelScenes?
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

    /// Forgets the edits, copies, thumbnails and tiles, as when another panel is shown.
    func forget() {
        drafts.forget()
        thumbnails.forget()
        tiles.forget()
    }
}

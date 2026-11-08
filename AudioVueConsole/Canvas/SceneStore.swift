import ConsoleCore
import Observation

/// What the Scenes page keeps while the app runs, owned by the App so it outlives the window: each
/// scene's edits and the copies Duplicate made, never saved (`scene-canvas`), the gallery's
/// thumbnails, and the card library's tiles.
@MainActor @Observable
final class SceneStore {
    let drafts = SceneDrafts()
    let thumbnails = SceneThumbnails()
    let tiles = LibraryTiles()
    /// The card kind being dragged from the library, set as the drag starts, so the canvas can
    /// preview its size before the drop delivers it.
    var draggedKind: String?
    /// How many drops the canvas has taken. The library's tiles are made again after each: once a
    /// tile's drop is refused, SwiftUI never calls its `onDrag` again (measured, 2026-11-07).
    var drops = 0

    /// Forgets the edits, copies, thumbnails and tiles, as when another panel is shown.
    func forget() {
        drafts.forget()
        thumbnails.forget()
        tiles.forget()
    }
}

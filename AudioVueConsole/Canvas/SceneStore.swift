import ConsoleCore
import Observation

/// What the Scenes page keeps while the app runs, owned by the App so it outlives the window: each
/// scene's edits and the copies Duplicate made, never saved (`scene-canvas`), and the gallery's
/// thumbnails.
@MainActor @Observable
final class SceneStore {
    let drafts = SceneDrafts()
    let thumbnails = SceneThumbnails()
    /// The card kind being dragged from the library, set as the drag starts, so the canvas can
    /// preview its size before the drop delivers it.
    var draggedKind: String?

    /// Forgets the edits, copies and thumbnails, as when another panel is shown.
    func forget() {
        drafts.forget()
        thumbnails.forget()
    }
}

import ConsoleCore
import SwiftUI

/// A card dragged in from the library: previewed at the pointer's cell while it hovers, added on
/// the drop. The library names the kind as the drag starts (`SceneStore.draggedKind`), since the
/// dragged text is not readable until the drop.
struct CanvasDropDelegate: DropDelegate {
    let editor: SceneEditor
    let geometry: GridGeometry
    let store: SceneStore
    let sizeOf: (String) -> CellSize?
    @Binding var gesture: CanvasGesture?

    func validateDrop(info: DropInfo) -> Bool {
        dragged != nil
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard let (kind, size) = dragged else { return DropProposal(operation: .forbidden) }
        gesture = .dropping(kind: kind, size: size, cell: geometry.cell(at: info.location))
        return DropProposal(operation: .copy)
    }

    func dropExited(info: DropInfo) {
        gesture = nil
    }

    func performDrop(info: DropInfo) -> Bool {
        defer {
            gesture = nil
            store.draggedKind = nil
        }
        guard let (kind, size) = dragged else { return false }
        editor.drop(kind: kind, size: size, at: geometry.cell(at: info.location))
        return editor.refusal == nil
    }

    private var dragged: (String, CellSize)? {
        guard let kind = store.draggedKind, let size = sizeOf(kind) else { return nil }
        return (kind, size)
    }
}

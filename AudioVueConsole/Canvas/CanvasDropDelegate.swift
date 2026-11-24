import ConsoleCore
import SwiftUI

/// A card dragged in from the library: previewed at the pointer's cell while it hovers, added on
/// the drop. The library names the kind as the drag starts (`SceneStore.draggedKind`), since the
/// dragged text is not readable until the drop.
struct CanvasDropDelegate: DropDelegate {
    let editor: SceneEditor
    /// The panel's grid placed in the pane, which takes drops on the panel and off it.
    let geometry: GridGeometry
    /// Where a card dropped off the panel may park: the pane in cells.
    let reach: CellRect
    let store: SceneStore
    let sizeOf: (String) -> CellSize?
    @Binding var gesture: CanvasGesture?

    func validateDrop(info: DropInfo) -> Bool {
        dragged != nil
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard let (kind, size) = dragged else { return DropProposal(operation: .forbidden) }
        gesture = .dropping(kind: kind, size: size, cell: geometry.cellOnOrOff(at: info.location))
        return DropProposal(operation: .copy)
    }

    func dropExited(info: DropInfo) {
        gesture = nil
    }

    func performDrop(info: DropInfo) -> Bool {
        defer {
            gesture = nil
            store.draggedKind = nil
            store.drops += 1
        }
        guard let (kind, size) = dragged else { return false }
        editor.drop(
            kind: kind, size: size, at: geometry.cellOnOrOff(at: info.location), within: reach)
        return editor.refusal == nil
    }

    private var dragged: (String, CellSize)? {
        guard let kind = store.draggedKind, let size = sizeOf(kind) else { return nil }
        return (kind, size)
    }
}

extension CanvasDropDelegate {
    /// Where a drop of `size` centred on `cell` would land, to outline: the new card's cells where
    /// `shown`, the editor's preview, takes it; else its block on the grid where `cell` is on it,
    /// or centred on `cell` off it.
    @MainActor
    static func outline(
        of size: CellSize, at cell: Cell, in editor: SceneEditor,
        shown: Result<SceneContent, LayoutRefusal>?
    ) -> CellRect {
        if case .success(let content)? = shown,
            let added = content.cards.first(where: { editor.content.card($0.id) == nil })
        {
            return added.cells
        }
        let layout = editor.layout
        let onGrid = layout.bounds.contains(
            CellRect(col: cell.col, row: cell.row, cols: 1, rows: 1))
        if onGrid, let placed = layout.placement(of: size, centredOn: cell) { return placed }
        return CellRect(
            col: cell.col - size.cols / 2, row: cell.row - size.rows / 2, cols: size.cols,
            rows: size.rows)
    }
}

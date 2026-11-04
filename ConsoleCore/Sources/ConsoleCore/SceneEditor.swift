import Foundation
import Observation

/// One scene's layout being edited: the selection, the last refusal, and undo. The canvas turns
/// pointer and key events into these calls and draws what they leave (`scene-canvas`).
@MainActor @Observable
public final class SceneEditor {
    public private(set) var layout: SceneLayout
    /// The selected cards, always whole groups.
    public private(set) var selection: Set<UUID> = []
    /// Why the last edit was refused, until the next edit or selection change.
    public private(set) var refusal: LayoutRefusal?
    /// Why the scene cannot be edited here, or nil when it can.
    public let readOnly: ReadOnlyReason?

    @ObservationIgnored private let undoManager: UndoManager?
    @ObservationIgnored private let onCommit: (SceneLayout) -> Void

    /// An editor for `layout`. Each committed layout goes to `onCommit`, so the app can keep it,
    /// and each edit is registered with `undoManager`.
    public init(
        layout: SceneLayout, readOnly: ReadOnlyReason? = nil, undoManager: UndoManager? = nil,
        onCommit: @escaping (SceneLayout) -> Void = { _ in }
    ) {
        self.layout = layout
        self.readOnly = readOnly
        self.undoManager = undoManager
        self.onCommit = onCommit
    }

    // MARK: Selection

    /// `id` alone, with its group.
    public func select(_ id: UUID) {
        setSelection(layout.widened([id]))
    }

    /// `id` and its group added to the selection, or taken out if already in it.
    public func toggle(_ id: UUID) {
        let reached = layout.widened([id])
        let isSelected = selection.isSuperset(of: reached)
        setSelection(isSelected ? selection.subtracting(reached) : selection.union(reached))
    }

    /// Every card touching `cells` selected, added to the selection when `adding`.
    public func select(touching cells: CellRect, adding: Bool = false) {
        let touched = Set(layout.cards.filter { $0.cells.intersects(cells) }.map(\.id))
        setSelection(layout.widened(touched).union(adding ? selection : []))
    }

    public func clearSelection() {
        setSelection([])
    }

    public var selectedCards: [LayoutCard] {
        layout.cards.filter { selection.contains($0.id) }
    }

    /// The selected card when it alone is selected, belongs to no group and the scene can be
    /// edited: the one card that shows resize handles.
    public var resizableCard: LayoutCard? {
        guard readOnly == nil, selection.count == 1, let card = selectedCards.first,
            card.group == nil
        else { return nil }
        return card
    }

    // MARK: Previews, which commit nothing

    public func previewMove(by offset: CellOffset) -> Result<SceneLayout, LayoutRefusal> {
        preview { () throws(LayoutRefusal) in try layout.moving(selection, by: offset) }
    }

    public func previewResize(_ id: UUID, edges: CardEdges, by offset: CellOffset)
        -> Result<SceneLayout, LayoutRefusal>
    {
        preview { () throws(LayoutRefusal) in try layout.resizing(id, edges: edges, by: offset) }
    }

    public func previewDrop(kind: String, size: CellSize, at cell: Cell)
        -> Result<SceneLayout, LayoutRefusal>
    {
        preview { () throws(LayoutRefusal) in
            try layout.adding(kind: kind, size: size, centredOn: cell)
        }
    }

    /// Why the selection cannot be grouped, or nil when it can.
    public var groupRefusal: LayoutRefusal? {
        if let readOnly { return .readOnly(readOnly) }
        do {
            _ = try layout.grouping(selection)
            return nil
        } catch {
            return error
        }
    }

    public var canUngroup: Bool {
        readOnly == nil && selectedCards.contains { $0.group != nil }
    }

    // MARK: Edits

    public func move(by offset: CellOffset) {
        commit("Move") { () throws(LayoutRefusal) in try layout.moving(selection, by: offset) }
    }

    public func resize(_ id: UUID, edges: CardEdges, by offset: CellOffset) {
        commit("Resize") { () throws(LayoutRefusal) in
            try layout.resizing(id, edges: edges, by: offset)
        }
    }

    /// A card of `kind` added centred on `cell`, and selected.
    public func drop(kind: String, size: CellSize, at cell: Cell) {
        let before = layout
        commit("Add Card") { () throws(LayoutRefusal) in
            try layout.adding(kind: kind, size: size, centredOn: cell)
        }
        if layout != before, let added = layout.cards.last { selection = [added.id] }
    }

    public func group() {
        commit("Group") { () throws(LayoutRefusal) in try layout.grouping(selection) }
    }

    public func ungroup() {
        commit("Ungroup") { () throws(LayoutRefusal) in layout.ungrouping(selection) }
    }

    public func deleteSelection() {
        commit("Delete") { () throws(LayoutRefusal) in layout.removing(selection) }
    }

    /// Removes this editor's undo actions, for when it leaves the screen and its window's
    /// manager outlives it.
    public func detach() {
        undoManager?.removeAllActions(withTarget: self)
    }

    // MARK: Committing and undo

    private func setSelection(_ ids: Set<UUID>) {
        selection = ids
        refusal = nil
    }

    private func preview(_ edit: () throws(LayoutRefusal) -> SceneLayout)
        -> Result<SceneLayout, LayoutRefusal>
    {
        if let readOnly { return .failure(.readOnly(readOnly)) }
        do {
            return .success(try edit())
        } catch {
            return .failure(error)
        }
    }

    /// Applies `edit` as one undoable step named `name`, or records its refusal. An edit that
    /// changes nothing adds no step.
    private func commit(_ name: String, _ edit: () throws(LayoutRefusal) -> SceneLayout) {
        switch preview(edit) {
        case .failure(let error):
            refusal = error
        case .success(let next) where next == layout:
            refusal = nil
        case .success(let next):
            registerUndo(name)
            let kept = Set(next.cards.map(\.id))
            show(next, selection: selection.intersection(kept))
        }
    }

    /// Registers the way back to the layout and selection as they are now. Registered while
    /// undoing, it becomes the redo.
    private func registerUndo(_ name: String) {
        let (layout, selection) = (layout, selection)
        undoManager?.beginUndoGrouping()
        undoManager?.registerUndo(withTarget: self) { editor in
            editor.registerUndo(name)
            editor.show(layout, selection: selection)
        }
        undoManager?.setActionName(name)
        undoManager?.endUndoGrouping()
    }

    private func show(_ layout: SceneLayout, selection: Set<UUID>) {
        self.layout = layout
        self.selection = selection
        refusal = nil
        onCommit(layout)
    }
}

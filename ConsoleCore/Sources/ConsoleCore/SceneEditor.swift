import Foundation
import Observation

/// One scene being edited, its layout and its blocks: the selection, the last refusal, and undo.
/// The canvas and the inspector turn events into these calls and draw what they leave
/// (`scene-canvas`, `scene-settings`).
@MainActor @Observable
public final class SceneEditor {
    /// The scene's layout and blocks, one undo history for both (`scene-settings`, design D1).
    public private(set) var content: SceneContent
    /// The selected cards, always whole groups.
    public private(set) var selection: Set<UUID> = []
    /// Why the last edit was refused, until the next edit or selection change.
    public private(set) var refusal: LayoutRefusal?
    /// Why the scene cannot be edited here, or nil when it can.
    public let readOnly: ReadOnlyReason?
    /// Each card's minimum on a grid `SchemaFacts.referenceRows` tall, by kind, as declared.
    @ObservationIgnored private let declaredMinimums: [String: CellSize]

    @ObservationIgnored private let undoManager: UndoManager?
    @ObservationIgnored private let onCommit: (SceneContent) -> Void

    /// An editor for `content`, each card's minimum in `minimums` as declared, on a grid
    /// `SchemaFacts.referenceRows` tall. Each committed content goes to `onCommit`, so the app
    /// can keep it, and each edit is registered with `undoManager`.
    public init(
        content: SceneContent, readOnly: ReadOnlyReason? = nil, minimums: [String: CellSize] = [:],
        undoManager: UndoManager? = nil, onCommit: @escaping (SceneContent) -> Void = { _ in }
    ) {
        self.content = content
        self.readOnly = readOnly
        declaredMinimums = minimums
        self.undoManager = undoManager
        self.onCommit = onCommit
    }

    /// An editor for `layout`, a scene with no blocks.
    public convenience init(
        layout: SceneLayout, readOnly: ReadOnlyReason? = nil, minimums: [String: CellSize] = [:],
        undoManager: UndoManager? = nil, onCommit: @escaping (SceneContent) -> Void = { _ in }
    ) {
        self.init(
            content: SceneContent(layout: layout), readOnly: readOnly, minimums: minimums,
            undoManager: undoManager, onCommit: onCommit)
    }

    /// The scene's cards on its grid.
    public var layout: SceneLayout { content.layout }

    /// Each card's minimum on the scene's grid as it is now, by kind; a kind with none may go
    /// down to a cell.
    public var minimums: [String: CellSize] {
        minimums(onRows: layout.grid.rows)
    }

    private func minimums(onRows rows: Int) -> [String: CellSize] {
        declaredMinimums.mapValues { SchemaFacts.scaled($0, toRows: rows) }
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
        preview { () throws(LayoutRefusal) in
            try layout.resizing(id, edges: edges, by: offset, minimum: minimum(of: id))
        }
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
            try layout.resizing(id, edges: edges, by: offset, minimum: minimum(of: id))
        }
    }

    /// The minimum of the card `id`, by its kind.
    private func minimum(of id: UUID) -> CellSize {
        layout.card(id).flatMap { minimums[$0.kind] } ?? .oneCell
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

    /// Sets the setting `key`, declared as `label`, to `value` on the cards `ids`: the whole
    /// selection from its shared settings, or one card from its own section (`card-settings`,
    /// design D4). The cards need not still be selected, so a colour chosen just before the
    /// selection changed still lands on the cards it was chosen for (design D8).
    public func set(_ key: String, to value: JSONValue, label: String, on ids: Set<UUID>) {
        commit("Change \(label)") { () throws(LayoutRefusal) in
            layout.setting(key, to: value, on: ids)
        }
    }

    /// Leaves the setting `key`, declared as `label`, unset on the cards `ids`, so each takes its
    /// own default. Not called reset, which is the panel's measurement reset.
    public func useDefault(_ key: String, label: String, on ids: Set<UUID>) {
        commit("Use Default for \(label)") { () throws(LayoutRefusal) in
            layout.unsetting(key, on: ids)
        }
    }

    /// Makes the grid `grid`, at the scene's aspect, moving every card to the cells covering the
    /// same part of the scene, as one step; refused where a card would fall below its minimum
    /// (`scene-settings`, design D5).
    public func setDensity(_ grid: CellSize) {
        commit("Change Density") { () throws(LayoutRefusal) in
            try GridDensity.relaid(layout, to: grid, minimums: minimums(onRows: grid.rows))
        }
    }

    /// What each backdrop source last held while this scene is edited (design D3).
    public private(set) var backdropMemory = BackdropMemory()

    /// Writes `source` as the scene's backdrop, as one step, remembering what the backdrop held,
    /// and bringing back the remembered angle where a gradient returns and the remembered blur
    /// where a source returns after None (design D3).
    public func setBackdrop(_ source: BackdropSource) {
        let block = content.blocks[Self.backdrop]
        let held = BackdropSource(block: block).kind
        backdropMemory.keep(block)
        var fields = source.written(over: block)
        if source.kind == .gradient, held != .gradient {
            fields[BackdropSource.angleKey] = backdropMemory.angle
        }
        if source != .unset, held == .unset {
            fields[BackdropSource.blurKey] = backdropMemory.blur
        }
        replace(block: Self.backdrop, with: fields, label: "Backdrop")
    }

    /// Switches the backdrop to `kind`, bringing back what that source last held, else starting
    /// from what it shows and `background`, the palette's (design D3). False where an image has to
    /// be chosen first, and nothing changes.
    public func switchBackdrop(to kind: BackdropSource.Kind, background: String) -> Bool {
        let block = content.blocks[Self.backdrop]
        backdropMemory.keep(block)
        guard
            let next = BackdropSource(block: block).switched(
                to: kind, background: background, memory: backdropMemory)
        else { return false }
        setBackdrop(next)
        return true
    }

    private static let backdrop = "backdrop"

    /// Sets the scene block `block`'s setting `key`, declared as `label`, to `value`
    /// (`scene-settings`, design D2).
    public func setBlock(_ block: String, _ key: String, to value: JSONValue, label: String) {
        var fields = content.blocks[block]?.objectValue ?? [:]
        fields[key] = value
        replace(block: block, with: fields, label: label)
    }

    /// Leaves the scene block `block`'s setting `key`, declared as `label`, unset, so the scene
    /// takes its default. A block left with no settings is removed.
    public func useDefault(block: String, key: String, label: String) {
        var fields = content.blocks[block]?.objectValue ?? [:]
        fields[key] = nil
        commitContent("Use Default for \(label)") { () throws(LayoutRefusal) in
            blocks(content, with: block, as: fields)
        }
    }

    /// Replaces the whole scene block `block` with `fields`, as one step named for `label`, as a
    /// backdrop's change of source is (design D3). Empty `fields` remove the block.
    public func replace(block: String, with fields: [String: JSONValue], label: String) {
        commitContent("Change \(label)") { () throws(LayoutRefusal) in
            blocks(content, with: block, as: fields)
        }
    }

    /// `content` with the block `block` holding `fields`, or without it where they are empty.
    private func blocks(_ content: SceneContent, with block: String, as fields: [String: JSONValue])
        -> SceneContent
    {
        var edited = content
        edited.blocks[block] = fields.isEmpty ? nil : .object(fields)
        return edited
    }

    /// Puts the scene back at `content`, as the host holds it, as one undoable step named Revert
    /// (`scene-saving`, "Revert discards unsaved edits"). `content` is of this editor's parse.
    public func revert(to content: SceneContent) {
        commitContent("Revert") { () throws(LayoutRefusal) in content }
    }

    /// Shows `content`, of another parse, with no undo step and none left from before: undoing
    /// across a change of parse would pair one version's cards with another's document
    /// (design D9).
    public func replace(with content: SceneContent) {
        detach()
        show(content, selection: [])
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

    private func preview<Edited>(_ edit: () throws(LayoutRefusal) -> Edited)
        -> Result<Edited, LayoutRefusal>
    {
        if let readOnly { return .failure(.readOnly(readOnly)) }
        do {
            return .success(try edit())
        } catch {
            return .failure(error)
        }
    }

    /// Applies `edit`, a layout edit, as one undoable step named `name` that keeps the blocks.
    private func commit(_ name: String, _ edit: () throws(LayoutRefusal) -> SceneLayout) {
        commitContent(name) { () throws(LayoutRefusal) in content.with(layout: try edit()) }
    }

    /// Applies `edit` as one undoable step named `name`, or records its refusal. An edit that
    /// changes nothing adds no step.
    private func commitContent(_ name: String, _ edit: () throws(LayoutRefusal) -> SceneContent) {
        switch preview(edit) {
        case .failure(let error):
            refusal = error
        case .success(let next) where next == content:
            refusal = nil
        case .success(let next):
            registerUndo(name)
            let kept = Set(next.layout.cards.map(\.id))
            show(next, selection: selection.intersection(kept))
        }
    }

    /// Registers the way back to the content and selection as they are now. Registered while
    /// undoing, it becomes the redo.
    private func registerUndo(_ name: String) {
        let (content, selection) = (content, selection)
        undoManager?.beginUndoGrouping()
        undoManager?.registerUndo(withTarget: self) { editor in
            editor.registerUndo(name)
            editor.show(content, selection: selection)
        }
        undoManager?.setActionName(name)
        undoManager?.endUndoGrouping()
    }

    private func show(_ content: SceneContent, selection: Set<UUID>) {
        self.content = content
        self.selection = selection
        refusal = nil
        onCommit(content)
    }
}

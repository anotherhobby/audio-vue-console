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
    /// Each card's declared minimum, by kind; a kind with none may go down to a cell.
    @ObservationIgnored public let minimums: [String: CellSize]

    @ObservationIgnored private let undoManager: UndoManager?
    @ObservationIgnored private let onCommit: (SceneContent) -> Void

    /// An editor for `content`, each card's minimum in `minimums` as declared. Each committed content goes to `onCommit`, so the app
    /// can keep it, and each edit is registered with `undoManager`.
    public init(
        content: SceneContent, readOnly: ReadOnlyReason? = nil, minimums: [String: CellSize] = [:],
        undoManager: UndoManager? = nil, onCommit: @escaping (SceneContent) -> Void = { _ in }
    ) {
        self.content = content
        self.readOnly = readOnly
        self.minimums = minimums
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

    // MARK: Selection

    /// `id` alone, with its group.
    public func select(_ id: UUID) {
        setSelection(content.widened([id]))
    }

    /// `id` and its group added to the selection, or taken out if already in it.
    public func toggle(_ id: UUID) {
        let reached = content.widened([id])
        let isSelected = selection.isSuperset(of: reached)
        setSelection(isSelected ? selection.subtracting(reached) : selection.union(reached))
    }

    /// Every card touching `cells`, on the grid or parked, selected, added to the selection when
    /// `adding`.
    public func select(touching cells: CellRect, adding: Bool = false) {
        let touched = Set(content.cards.filter { $0.cells.intersects(cells) }.map(\.id))
        setSelection(content.widened(touched).union(adding ? selection : []))
    }

    public func clearSelection() {
        setSelection([])
    }

    /// The selected cards, on the grid then parked.
    public var selectedCards: [LayoutCard] {
        content.cards.filter { selection.contains($0.id) }
    }

    /// The selected card when it alone is selected, on the grid or parked, belongs to no group and
    /// the scene can be edited: the one card that shows resize handles.
    public var resizableCard: LayoutCard? {
        guard readOnly == nil, selection.count == 1, let card = selectedCards.first,
            card.group == nil
        else { return nil }
        return card
    }

    /// Whether any card is parked off the panel (`card-parking`).
    public var hasParked: Bool { !content.parked.isEmpty }

    /// The library card selected in place of the canvas's selection, by name (`library-setup`).
    public internal(set) var libraryCard: String?
    /// Each library card's setup by name: the settings a card dropped from the library takes. Not
    /// part of the scene, so outside undo, and gone with the editor (`library-setup`, design D5).
    public internal(set) var setups: [String: [String: JSONValue]] = [:]

    // MARK: Previews, which commit nothing

    /// The scene as dragging the selection by `offset` would leave it, parked cards included, kept
    /// to `reach`, the pane in cells (`card-parking`).
    public func previewDrag(by offset: CellOffset, within reach: CellRect)
        -> Result<SceneContent, LayoutRefusal>
    {
        preview { () throws(LayoutRefusal) in
            try content.dragging(selection, by: offset, within: reach)
        }
    }

    /// The scene as resizing the card `id` would leave it, a parked one kept to `reach`, the pane
    /// in cells.
    public func previewResize(
        _ id: UUID, edges: CardEdges, by offset: CellOffset, within reach: CellRect
    ) -> Result<SceneContent, LayoutRefusal> {
        preview { () throws(LayoutRefusal) in
            try content.resizing(
                id, edges: edges, by: offset, minimum: minimum(of: id), within: reach)
        }
    }

    /// The scene as dropping a library card of `kind` and `size` centred on `cell` would leave it:
    /// on the grid where `cell` is on it, parked within `reach`, the pane in cells, where it is off
    /// (`card-parking`, design D10).
    public func previewDrop(kind: String, size: CellSize, at cell: Cell, within reach: CellRect)
        -> Result<SceneContent, LayoutRefusal>
    {
        preview { () throws(LayoutRefusal) in
            try content.dropping(dropped(kind, size), at: cell, within: reach)
        }
    }

    /// Why the selection cannot be grouped, or nil when it can.
    public var groupRefusal: LayoutRefusal? {
        if let readOnly { return .readOnly(readOnly) }
        do {
            _ = try content.grouping(selection)
            return nil
        } catch {
            return error
        }
    }

    public var canUngroup: Bool {
        readOnly == nil && selectedCards.contains { $0.group != nil }
    }

    // MARK: Edits

    /// The selection dragged by `offset`, parking it where it leaves the grid and returning it
    /// where it lands wholly on it, kept to `reach` (`card-parking`).
    public func drag(by offset: CellOffset, within reach: CellRect) {
        commitContent("Move") { () throws(LayoutRefusal) in
            try content.dragging(selection, by: offset, within: reach)
        }
    }

    /// The selection nudged by an arrow key's `offset`, which never takes a card across the
    /// panel's edge, parked cards kept to `reach` (`card-parking`).
    public func nudge(by offset: CellOffset, within reach: CellRect) {
        commitContent("Move") { () throws(LayoutRefusal) in
            try content.nudging(selection, by: offset, within: reach)
        }
    }

    /// The card `id` resized, on the grid or parked within `reach`, as one step named Resize.
    public func resize(
        _ id: UUID, edges: CardEdges, by offset: CellOffset, within reach: CellRect
    ) {
        commitContent("Resize") { () throws(LayoutRefusal) in
            try content.resizing(
                id, edges: edges, by: offset, minimum: minimum(of: id), within: reach)
        }
    }

    /// The minimum of the card `id`, on the grid or parked, by its kind.
    private func minimum(of id: UUID) -> CellSize {
        content.card(id).flatMap { minimums[$0.kind] } ?? .oneCell
    }

    /// A card of `kind` added centred on `cell`, on the grid or parked within `reach` as
    /// `previewDrop` shows, with its library setup as it stands, and selected (`library-setup`,
    /// "A dropped card takes its library setup").
    public func drop(kind: String, size: CellSize, at cell: Cell, within reach: CellRect) {
        let card = dropped(kind, size)
        commitContent("Add Card", selecting: [card.id]) { () throws(LayoutRefusal) in
            try content.dropping(card, at: cell, within: reach)
        }
    }

    /// A new card of `kind` at `size`, with its library setup: what a drop adds.
    private func dropped(_ kind: String, _ size: CellSize) -> LayoutCard {
        LayoutCard(
            kind: kind, cells: CellRect(col: 0, row: 0, cols: size.cols, rows: size.rows),
            settings: setups[kind] ?? [:])
    }

    /// The selection made one group, on the grid or parked (`card-parking`, design D11).
    public func group() {
        commitContent("Group") { () throws(LayoutRefusal) in try content.grouping(selection) }
    }

    public func ungroup() {
        commitContent("Ungroup") { () throws(LayoutRefusal) in content.ungrouping(selection) }
    }

    public func deleteSelection() {
        commitContent("Delete") { () throws(LayoutRefusal) in content.removing(selection) }
    }

    /// Sets the setting `key`, declared as `label`, to `value` on the cards `ids`: the whole
    /// selection from its shared settings, or one card from its own section (`card-settings`,
    /// design D4). The cards need not still be selected, so a colour chosen just before the
    /// selection changed still lands on the cards it was chosen for (design D8).
    public func set(_ key: String, to value: JSONValue, label: String, on ids: Set<UUID>) {
        commitContent("Change \(label)") { () throws(LayoutRefusal) in
            content.setting(key, to: value, on: ids)
        }
    }

    /// Changes the setting `key`, declared as `label`, on each card in `ids` to `transform` of that
    /// card's own value, as one step (`meter-scales-editor`, design D3).
    public func editSetting(
        _ key: String, label: String, on ids: Set<UUID>, _ transform: (JSONValue?) -> JSONValue?
    ) {
        commitContent("Change \(label)") { () throws(LayoutRefusal) in
            content.changingSetting(key, on: ids, transform)
        }
    }

    /// Leaves the setting `key`, declared as `label`, unset on the cards `ids`, so each takes its
    /// own default. Not called reset, which is the panel's measurement reset.
    public func useDefault(_ key: String, label: String, on ids: Set<UUID>) {
        commitContent("Use Default for \(label)") { () throws(LayoutRefusal) in
            content.unsetting(key, on: ids)
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

    /// Sets the backdrop's gradient to the stops and angle of `standard`, the default look's
    /// backdrop, as one step. Nothing where it is no gradient or the scene already holds it.
    public func useDefaultGradient(_ standard: JSONValue?) {
        guard
            let fields = BackdropSource.gradient(
                of: standard, over: content.blocks[Self.backdrop])
        else { return }
        replace(block: Self.backdrop, with: fields, label: "Backdrop")
    }

    /// Switches the backdrop to `kind`, bringing back what that source last held, else starting
    /// from what it shows and `background`, the scene's card colour (design D3). False where an image has to
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

    /// Selects `ids`, which leaves no library card selected.
    private func setSelection(_ ids: Set<UUID>) {
        selection = ids
        libraryCard = nil
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

    /// Applies `edit` as one undoable step named `name`, or records its refusal. An edit that
    /// changes nothing adds no step. A made edit selects `selecting`, else what is left of the
    /// selection.
    func commitContent(
        _ name: String, selecting: Set<UUID>? = nil,
        _ edit: () throws(LayoutRefusal) -> SceneContent
    ) {
        switch preview(edit) {
        case .failure(let error):
            refusal = error
        case .success(let next) where next == content:
            refusal = nil
        case .success(let next):
            registerUndo(name)
            let kept = Set(next.cards.map(\.id))
            show(next, selection: selecting ?? selection.intersection(kept))
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
        if !selection.isEmpty { libraryCard = nil }
        refusal = nil
        onCommit(content)
    }
}

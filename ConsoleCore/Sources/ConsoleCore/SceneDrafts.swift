import Foundation
import Observation

/// What the app holds of a panel's scenes beyond what the host has: each opened scene's draft, and
/// the copies Duplicate made, kept until saved or discarded (`scene-canvas`, "Edits are kept until
/// saved or discarded"; `scene-gallery`, "Duplicate makes an unsaved copy").
@MainActor @Observable
public final class SceneDrafts {
    /// The copies made in the app, newest last.
    public private(set) var copies: [SceneDocument] = []
    private var drafts: [String: Draft] = [:]
    /// Each scene's last repair, for the document and the shape it was found for: a walk takes
    /// about a millisecond for a gallery, which draws each row many times (design D4).
    @ObservationIgnored private var repairs: [String: HeldRepair] = [:]

    private struct HeldRepair {
        let shape: UUID
        let doc: JSONValue
        let repair: SceneRepair?
    }

    public init() {}

    /// The scene `id`'s draft, or nil where it has not been opened.
    public func draft(_ id: String) -> Draft? {
        drafts[id]
    }

    /// `document`'s draft, made from one parse the first time and the same after that.
    public func draft(for document: SceneDocument, panel: CellSize) throws(LayoutRefusal)
        -> Draft
    {
        if let draft = drafts[document.id] { return draft }
        let draft = Draft(try LaidOutScene(document, panel: panel))
        drafts[document.id] = draft
        return draft
    }

    /// Keeps `content` as the scene `id`'s, an edit of its draft's parse.
    public func keep(_ content: SceneContent, for id: String) {
        drafts[id]?.content = content
    }

    /// The host's `scenes` with the app's copies after them.
    public func listing(_ scenes: [SceneDocument]) -> [SceneDocument] {
        scenes + copies
    }

    /// The drafts not saved, in `scenes`' listing order: what a quit or a switch of panel would lose.
    public func unsaved(_ scenes: [SceneDocument]) -> [Draft] {
        listing(scenes).compactMap { drafts[$0.id] }.filter(\.isUnsaved)
    }

    /// A new scene with no cards, laid out on `grid`, the panel's, kept with the app's copies until saved, named "New
    /// Scene", or "New Scene 2" and on, the first no scene of `scenes` or copy has.
    public func new(on grid: CellSize, among scenes: [SceneDocument]) throws(LayoutRefusal)
        -> SceneDocument
    {
        let name = Self.free("New Scene", among: listing(scenes))
        let doc: JSONValue = .object([
            "name": .string(name), "cards": .array([]),
        ])
        let scene = SceneDocument(
            id: "\(Self.copyPrefix)\(UUID().uuidString)", name: name, builtIn: false,
            fixed: false, doc: doc)
        let draft = Draft(try LaidOutScene(scene, panel: grid))
        copies.append(scene)
        drafts[scene.id] = draft
        return scene
    }

    /// `base`, or `base` with 2 and on after it, the first no scene of `scenes` is named.
    private static func free(_ base: String, among scenes: [SceneDocument]) -> String {
        let taken = Set(scenes.compactMap(\.name))
        var name = base
        var number = 2
        while taken.contains(name) {
            name = "\(base) \(number)"
            number += 1
        }
        return name
    }

    /// A copy of `draft` as it now shows, kept with the app's copies, not built in, named for it
    /// with "copy" after it, or "copy 2" and on, the first no scene of `scenes` or copy has.
    public func duplicate(_ draft: Draft, among scenes: [SceneDocument]) -> SceneDocument {
        let name = Self.free("\(draft.name ?? draft.id) copy", among: listing(scenes))
        var doc = draft.doc.objectValue ?? [:]
        doc["name"] = .string(name)
        let copy = SceneDocument(
            id: "\(Self.copyPrefix)\(UUID().uuidString)", name: name, builtIn: false, fixed: false,
            doc: .object(doc))
        copies.append(copy)
        drafts[copy.id] = Draft(
            draft.laidOut.copy(draft.content, as: copy), content: draft.content, name: name,
            rev: nil
        )
        return copy
    }

    /// Takes a save of the scene `id`, now stored as `document` (design D3): the draft becomes the
    /// host's document read afresh, not unsaved, and a copy's draft moves to the id the host gave.
    public func saved(_ document: SceneDocument, was id: String) {
        guard let old = drafts.removeValue(forKey: id) else { return }
        copies.removeAll { $0.id == id }
        drafts[document.id] = reread(document, keeping: old)
    }

    /// Takes a rename of the stored scene `id`, now stored as `document` (design D4). A clean draft
    /// is read afresh; an unsaved one keeps its parse and layout, and only its base moves, so a
    /// later Save writes the new name on the new revision.
    public func renamed(_ id: String, to document: SceneDocument) {
        guard let old = drafts[id] else { return }
        guard old.isUnsaved else {
            drafts[id] = reread(document, keeping: old)
            return
        }
        // Only the name changed, so a parse of the held revision is of the new one too.
        if old.source == old.rev { drafts[id]?.source = document.rev }
        drafts[id]?.name = document.name
        drafts[id]?.rev = document.rev
    }

    /// Loads `revision`, an earlier version of the scene `id`, as an unsaved edit under the
    /// draft's name, kept on the current revision so a save is not stale (design D9). The parse
    /// changes, so the editor shows the draft's layout afresh.
    public func load(_ revision: SceneRevision, for id: String) throws(LayoutRefusal) {
        guard let old = drafts[id] else { return }
        var doc = revision.doc.objectValue ?? [:]
        if let name = old.name { doc["name"] = .string(name) }
        let document = SceneDocument(
            id: id, name: old.name, builtIn: false, fixed: false, doc: .object(doc),
            rev: revision.rev)
        var draft = Draft(try LaidOutScene(document, panel: old.laidOut.panel))
        draft.rev = old.rev
        drafts[id] = draft
    }

    /// The repair `document` needs to pass `shape` (`scene-repair`, design D4): of its draft as a
    /// save would write it where it has one, else as the host holds it, and none for a built-in,
    /// which the host ships valid.
    public func repair(of document: SceneDocument, shape: SceneShape) -> SceneRepair? {
        guard !document.builtIn else { return nil }
        let doc = drafts[document.id]?.doc ?? document.doc
        if let held = repairs[document.id], held.shape == shape.identity, held.doc == doc {
            return held.repair
        }
        let repair = shape.repair(of: doc)
        repairs[document.id] = HeldRepair(shape: shape.identity, doc: doc, repair: repair)
        return repair
    }

    /// Repairs the scene `id` as `repair` says (`scene-repair`, design D5): its repaired document
    /// laid out afresh on the draft's panel as an unsaved edit on the same revision, each card
    /// the repair keeps holding its id. The parse changes, so the editor shows the draft afresh.
    public func repair(_ id: String, with repair: SceneRepair) throws(LayoutRefusal) {
        guard let old = drafts[id], let doc = repair.doc else { return }
        let ids = old.laidOut.layout.cards.map(\.id).enumerated()
            .filter { !repair.removedCards.contains($0.offset) }.map(\.element)
        let document = SceneDocument(
            id: id, name: old.laidOut.document.name, builtIn: false, fixed: false, doc: doc,
            rev: old.laidOut.document.rev)
        var draft = Draft(try LaidOutScene(document, panel: old.laidOut.panel, ids: ids))
        draft.name = old.name
        draft.rev = old.rev
        draft.repaired = true
        drafts[id] = draft
    }

    /// Reverts the scene `id` to `base`, the host's current document: the content to show, and
    /// whether it is of a new parse, as after a version was loaded, when the editor's undo cannot
    /// reach it. Of the same parse, the draft is left for the editor's undoable Revert to keep.
    public func revert(_ id: String, to base: SceneDocument) throws(LayoutRefusal)
        -> (content: SceneContent, newParse: Bool)?
    {
        guard let old = drafts[id] else { return nil }
        guard old.source != old.rev || old.repaired else { return (old.laidOut.content, false) }
        let draft = Draft(try LaidOutScene(base, panel: old.laidOut.panel))
        drafts[id] = draft
        return (draft.content, true)
    }

    /// Renames the copy `id`, never saved, in the app alone.
    public func renameCopy(_ id: String, to name: String) {
        guard let index = copies.firstIndex(where: { $0.id == id }) else { return }
        let copy = copies[index]
        var doc = copy.doc.objectValue ?? [:]
        doc["name"] = .string(name)
        copies[index] = SceneDocument(
            id: id, name: name, builtIn: false, fixed: false, doc: .object(doc))
        drafts[id]?.name = name
    }

    /// Drops the scene `id`'s draft, and the copy where `id` is one: Discard Mine, a delete, or
    /// Discard before a quit or a switch of panel.
    public func discard(_ id: String) {
        drafts[id] = nil
        copies.removeAll { $0.id == id }
    }

    /// Lays every draft out again on `panel`, the panel's grid now, as when its display changes.
    /// An edited draft keeps its blocks and each card it moved or resized; a card left as read
    /// takes its cells on the new grid, so an unset span covers it. A draft that cannot be laid
    /// out there is dropped, and the next open says why.
    public func relay(on panel: CellSize) {
        for (id, old) in drafts where old.laidOut.panel != panel {
            drafts[id] = Self.relaid(old, on: panel)
        }
    }

    private static func relaid(_ old: Draft, on panel: CellSize) -> Draft? {
        do throws(LayoutRefusal) {
            let ids = old.laidOut.layout.cards.map(\.id)
            let base = try LaidOutScene(old.laidOut.document, panel: panel, ids: ids)
            let asRead = Dictionary(
                uniqueKeysWithValues: old.laidOut.layout.cards.map { ($0.id, $0.cells) })
            let cards = old.layout.cards.map { card in
                var moved = card
                if asRead[card.id] == card.cells, let now = base.layout.card(card.id) {
                    moved.cells = now.cells
                }
                return moved
            }
            let reach = cards.map(\.cells.maxCol).max() ?? 0
            let layout = try SceneLayout(
                grid: CellSize(cols: max(panel.cols, reach), rows: panel.rows), cards: cards)
            var draft = Draft(
                base,
                content: SceneContent(
                    layout: layout, blocks: old.content.blocks, entries: old.content.entries),
                name: old.name, rev: old.rev)
            draft.source = old.source
            draft.repaired = old.repaired
            return draft
        } catch {
            return nil
        }
    }

    /// Forgets every draft and copy, as when another panel is shown.
    public func forget() {
        copies = []
        drafts = [:]
    }

    /// `document` as a draft read afresh, its cards keeping `old`'s ids so an open editor's layout
    /// still pairs with it, or nil where it cannot be read, so the next open says why.
    private func reread(_ document: SceneDocument, keeping old: Draft) -> Draft? {
        do {
            return Draft(
                try LaidOutScene(
                    document, panel: old.laidOut.panel, ids: old.layout.cards.map(\.id),
                    keeping: old.layout))
        } catch {
            return nil
        }
    }

    /// Whether `id` names a copy made in the app.
    nonisolated public static func isCopy(_ id: String) -> Bool {
        id.hasPrefix(copyPrefix)
    }

    nonisolated private static let copyPrefix = "copy-"
}

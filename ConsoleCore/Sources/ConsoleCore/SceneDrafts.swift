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

    public init() {}

    /// The scene `id`'s draft, or nil where it has not been opened.
    public func draft(_ id: String) -> Draft? {
        drafts[id]
    }

    /// `document`'s draft, made from one parse the first time and the same after that.
    public func draft(for document: SceneDocument, defaultGrid: CellSize) throws(LayoutRefusal)
        -> Draft
    {
        if let draft = drafts[document.id] { return draft }
        let draft = Draft(try LaidOutScene(document, defaultGrid: defaultGrid))
        drafts[document.id] = draft
        return draft
    }

    /// Keeps `layout` as the scene `id`'s, an edit of its draft's parse.
    public func keep(_ layout: SceneLayout, for id: String) {
        drafts[id]?.layout = layout
    }

    /// The host's `scenes` with the app's copies after them.
    public func listing(_ scenes: [SceneDocument]) -> [SceneDocument] {
        scenes + copies
    }

    /// The drafts not saved, in `scenes`' listing order: what a quit or a switch of panel would lose.
    public func unsaved(_ scenes: [SceneDocument]) -> [Draft] {
        listing(scenes).compactMap { drafts[$0.id] }.filter(\.isUnsaved)
    }

    /// A copy of `draft` as it now shows, kept with the app's copies, not built in, named for it
    /// with "copy" after it, or "copy 2" and on, the first no scene of `scenes` or copy has.
    public func duplicate(_ draft: Draft, among scenes: [SceneDocument]) -> SceneDocument {
        let base = "\(draft.name ?? draft.id) copy"
        let taken = Set(listing(scenes).compactMap(\.name))
        var name = base
        var number = 2
        while taken.contains(name) {
            name = "\(base) \(number)"
            number += 1
        }
        var doc = draft.doc.objectValue ?? [:]
        doc["name"] = .string(name)
        let copy = SceneDocument(
            id: "\(Self.copyPrefix)\(UUID().uuidString)", name: name, builtIn: false, fixed: false,
            doc: .object(doc))
        copies.append(copy)
        drafts[copy.id] = Draft(
            draft.laidOut.copy(draft.layout, as: copy), layout: draft.layout, name: name, rev: nil)
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
        var draft = Draft(try LaidOutScene(document, defaultGrid: old.layout.grid))
        draft.rev = old.rev
        drafts[id] = draft
    }

    /// Reverts the scene `id` to `base`, the host's current document: the layout to show, and
    /// whether it is of a new parse, as after a version was loaded, when the editor's undo cannot
    /// reach it. Of the same parse, the draft is left for the editor's undoable Revert to keep.
    public func revert(_ id: String, to base: SceneDocument) throws(LayoutRefusal)
        -> (layout: SceneLayout, newParse: Bool)?
    {
        guard let old = drafts[id] else { return nil }
        guard old.source != old.rev else { return (old.laidOut.layout, false) }
        let draft = Draft(try LaidOutScene(base, defaultGrid: old.layout.grid))
        drafts[id] = draft
        return (draft.layout, true)
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
                    document, defaultGrid: old.layout.grid, ids: old.layout.cards.map(\.id)))
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

import Foundation

/// One scene as the app edits it (design D1): the parse it was opened on, its layout now, and its
/// base, the name and revision a save is written with. A layout's card ids belong to the parse it
/// came from, so a draft is turned back into a document only through its own `laidOut`.
public struct Draft: Sendable, Equatable {
    public internal(set) var laidOut: LaidOutScene
    public internal(set) var layout: SceneLayout
    /// The name a save writes, which a rename moves without touching the layout.
    public internal(set) var name: String?
    /// The revision a save is written on: nil for a built-in and a copy never saved.
    public internal(set) var rev: Int?
    /// The revision the parse was read from: `rev`, or an earlier one loaded from Versions.
    public internal(set) var source: Int?

    init(_ laidOut: LaidOutScene) {
        self.laidOut = laidOut
        layout = laidOut.layout
        name = laidOut.document.name
        rev = laidOut.document.rev
        source = rev
    }

    init(_ laidOut: LaidOutScene, layout: SceneLayout, name: String?, rev: Int?) {
        self.laidOut = laidOut
        self.layout = layout
        self.name = name
        self.rev = rev
        source = rev
    }

    public var id: String { laidOut.document.id }

    /// Whether the host does not hold what the draft shows: a copy never saved, an earlier version
    /// loaded, or a layout that differs from the one read. Both layouts carry the parse's card ids,
    /// so undoing back to the read layout clears it.
    public var isUnsaved: Bool {
        SceneDrafts.isCopy(id) || source != rev || layout != laidOut.layout
    }

    /// The document a save writes: the parse's document with the cards as `layout` places them,
    /// under the draft's name.
    public var doc: JSONValue {
        var fields = laidOut.doc(for: layout).objectValue ?? [:]
        if let name, !name.isEmpty { fields["name"] = .string(name) }
        return .object(fields)
    }
}

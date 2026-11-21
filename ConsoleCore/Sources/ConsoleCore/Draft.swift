import Foundation

/// One scene as the app edits it (design D1): the parse it was opened on, its content now, and its
/// base, the name and revision a save is written with. A layout's card ids belong to the parse it
/// came from, so a draft is turned back into a document only through its own `laidOut`.
public struct Draft: Sendable, Equatable {
    public internal(set) var laidOut: LaidOutScene
    /// The scene's layout and blocks as edited (`scene-settings`, design D1).
    public internal(set) var content: SceneContent
    /// The name a save writes, which a rename moves without touching the layout.
    public internal(set) var name: String?
    /// The revision a save is written on: nil for a built-in and a copy never saved.
    public internal(set) var rev: Int?
    /// The revision the parse was read from: `rev`, or an earlier one loaded from Versions.
    public internal(set) var source: Int?

    /// The scene as read, with no edit.
    public init(_ laidOut: LaidOutScene) {
        self.laidOut = laidOut
        content = laidOut.content
        name = laidOut.document.name
        rev = laidOut.document.rev
        source = rev
    }

    init(_ laidOut: LaidOutScene, content: SceneContent, name: String?, rev: Int?) {
        self.laidOut = laidOut
        self.content = content
        self.name = name
        self.rev = rev
        source = rev
    }

    public var id: String { laidOut.document.id }

    /// The scene's cards on its grid as edited.
    public var layout: SceneLayout { content.layout }

    /// Whether the host does not hold what the draft shows: a copy never saved, an earlier version
    /// loaded, content that differs from the one read, or a stored grid size, which a save
    /// removes. Both layouts carry the parse's card ids, so undoing back to the content read
    /// clears it, a block changed and changed back included.
    public var isUnsaved: Bool {
        SceneDrafts.isCopy(id) || source != rev || content != laidOut.content
            || laidOut.declaresGridSize
    }

    /// The document a save writes: the parse's document with the blocks and cards as `content`
    /// holds them, under the draft's name.
    public var doc: JSONValue {
        var fields = laidOut.doc(for: content).objectValue ?? [:]
        if let name, !name.isEmpty { fields["name"] = .string(name) }
        return .object(fields)
    }
}

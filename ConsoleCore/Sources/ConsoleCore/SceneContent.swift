/// What a scene's edits change (`scene-settings`, design D1): its cards on the grid, and its own
/// blocks, every top-level key of its document but `cards` and `name`. The grid's `cols` and `rows`
/// are the layout's; `grid` in `blocks` holds the rest of that block, such as `gap`.
public struct SceneContent: Sendable, Hashable {
    public var layout: SceneLayout
    /// The scene's blocks as edited, by key, each as its document holds it.
    public var blocks: [String: JSONValue]

    public init(layout: SceneLayout, blocks: [String: JSONValue] = [:]) {
        self.layout = layout
        self.blocks = blocks
    }

    /// This content with its cards placed as `layout` places them.
    public func with(layout: SceneLayout) -> SceneContent {
        SceneContent(layout: layout, blocks: blocks)
    }

    /// The blocks of the scene document `doc`: its keys but `cards` and `name`.
    static func blocks(of doc: JSONValue) -> [String: JSONValue] {
        (doc.objectValue ?? [:]).filter { !notBlocks.contains($0.key) }
    }

    private static let notBlocks: Set<String> = ["cards", "name"]
}

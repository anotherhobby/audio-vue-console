/// A scene as the gallery sorts it: whether it is built in, and the grid it is laid out on.
public protocol GalleryEntry {
    var builtIn: Bool { get }
    /// The scene's laid-out grid, or nil where it cannot be laid out.
    var grid: CellSize? { get }
}

/// The Scenes gallery's sections (`scene-gallery`, "My scenes, then the built-ins, then other
/// shapes"): the scenes of the panel's shape not built in, those built in, then every scene of
/// another shape, each in the order given. A scene that cannot be laid out is placed by the
/// default grid.
public struct GallerySections<Entry: GalleryEntry> {
    public let mine: [Entry]
    public let builtIn: [Entry]
    public let otherShapes: [Entry]

    public init(_ entries: [Entry], panel: DisplayShape, defaultGrid: CellSize) {
        let fits = { (entry: Entry) in
            let grid = entry.grid ?? defaultGrid
            return panel.matches(DisplayShape(width: grid.cols, height: grid.rows))
        }
        mine = entries.filter { fits($0) && !$0.builtIn }
        builtIn = entries.filter { fits($0) && $0.builtIn }
        otherShapes = entries.filter { !fits($0) }
    }
}

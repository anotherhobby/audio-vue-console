/// A scene as the gallery sorts it: whether it is built in.
public protocol GalleryEntry {
    var builtIn: Bool { get }
}

/// The Scenes gallery's sections (`scene-gallery`, "My scenes, then the built-ins"): the scenes
/// not built in, then those built in, each in the order given.
public struct GallerySections<Entry: GalleryEntry> {
    public let mine: [Entry]
    public let builtIn: [Entry]

    public init(_ entries: [Entry]) {
        mine = entries.filter { !$0.builtIn }
        builtIn = entries.filter(\.builtIn)
    }
}

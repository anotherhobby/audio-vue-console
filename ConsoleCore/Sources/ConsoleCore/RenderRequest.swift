import Foundation

/// A size in display pixels.
public struct PixelSize: Sendable, Hashable {
    public let width: Int
    public let height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    /// What a scene is drawn at when the host gives no display size, 1920 by 1080, the 16:9 a
    /// panel is taken to be when it cannot be told (`scene-rendering`).
    public static let unknownPanel = PixelSize(width: unknownWidth, height: unknownHeight)
    private static let unknownWidth = 1920
    private static let unknownHeight = 1080
}

/// What every render request for one panel carries besides the scene: the panel's display size,
/// the install's viewing block, where the host's images are kept, and the stored styles scenes
/// name, by id (`scene-rendering`, "A request carries the host's scene and settings").
public struct RenderContext: Sendable, Equatable {
    public let display: PixelSize
    public let viewing: JSONValue
    public let images: URL
    public let styles: [String: JSONValue]

    public init(
        display: PixelSize, viewing: JSONValue, images: URL, styles: [String: JSONValue] = [:]
    ) {
        self.display = display
        self.viewing = viewing
        self.images = images
        self.styles = styles
    }

    /// What a request to draw `doc` carries from this context, as `render` and `track` both take
    /// it: the scene, whether it is built in, the display, the viewing, the images directory and the
    /// stored styles the scene names (the helper carries the built-in ones itself).
    public func fields(for doc: JSONValue, builtIn: Bool) -> [String: JSONValue] {
        let named = (doc["styles"]?.arrayValue ?? []).compactMap(\.stringValue)
        return [
            "scene": doc, "built_in": .bool(builtIn),
            "display": .array([.integer(display.width), .integer(display.height)]),
            "viewing": viewing, "images": .string(images.path),
            "styles": .object(styles.filter { named.contains($0.key) }),
        ]
    }
}

/// One `render` request: a scene's document as the store holds it, whether it is built in, the
/// panel's context, and optionally the plates wanted and whether the backdrop is.
public struct RenderRequest: Sendable, Equatable {
    /// The rate every preview is drawn at: the rate does not matter to a preview, so one is picked
    /// and every scene shares the prepared run (maintainer, 2026-11-07).
    public static let previewRate = 48_000

    /// The scene blocks no render reads, so a change to them draws nothing again: `display` holds
    /// the idle stages and the screensaver's look, which audio-vue reads only when the display
    /// idles (`scene_model`: `scene.display`, `scene.saver_look`; `track-native-logo` design D7).
    public static let undrawnBlocks: Set<String> = ["display"]

    public let doc: JSONValue
    public let builtIn: Bool
    public let context: RenderContext
    /// Placement indices, one per plate wanted, or nil for every plate.
    public let plates: [Int]?
    public let backdrop: Bool

    public init(
        doc: JSONValue, builtIn: Bool, context: RenderContext, plates: [Int]? = nil,
        backdrop: Bool = true
    ) {
        self.doc = doc
        self.builtIn = builtIn
        self.context = context
        self.plates = plates
        self.backdrop = backdrop
    }

    /// The request as the helper reads it.
    public var message: JSONValue {
        var fields = context.fields(for: doc, builtIn: builtIn)
        fields["op"] = .string("render")
        fields["rate"] = .integer(Self.previewRate)
        fields["backdrop"] = .bool(backdrop)
        if let plates { fields["plates"] = .array(plates.map(JSONValue.integer)) }
        return .object(fields)
    }
}

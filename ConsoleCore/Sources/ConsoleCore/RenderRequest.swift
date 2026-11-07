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
/// the install's fonts block, where the host's images are kept, and the backdrop drawn for an
/// image that is not there (`scene-rendering`, "A request carries the host's scene and settings").
public struct RenderContext: Sendable, Equatable {
    public let display: PixelSize
    public let fonts: JSONValue
    public let images: URL
    public let fallback: JSONValue

    public init(display: PixelSize, fonts: JSONValue, images: URL, fallback: JSONValue) {
        self.display = display
        self.fonts = fonts
        self.images = images
        self.fallback = fallback
    }
}

/// One `render` request: a scene's document as the store holds it, whether it is built in, the
/// panel's context, and optionally the plates wanted and whether the backdrop is.
public struct RenderRequest: Sendable, Equatable {
    /// The rate every preview is drawn at: the rate does not matter to a preview, so one is picked
    /// and every scene shares the prepared run (maintainer, 2026-11-07).
    public static let previewRate = 48_000

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
        var fields: [String: JSONValue] = [
            "op": .string("render"), "scene": doc, "built_in": .bool(builtIn),
            "display": .array([.integer(context.display.width), .integer(context.display.height)]),
            "fonts": context.fonts, "rate": .integer(Self.previewRate),
            "images": .string(context.images.path), "fallback": context.fallback,
            "backdrop": .bool(backdrop),
        ]
        if let plates { fields["plates"] = .array(plates.map(JSONValue.integer)) }
        return .object(fields)
    }
}

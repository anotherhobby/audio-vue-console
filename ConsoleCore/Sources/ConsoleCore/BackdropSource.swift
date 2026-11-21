/// The one source a scene's backdrop holds: none, a colour, a gradient or an image, since the host
/// refuses a backdrop with more than one (audio-vue `scene-backdrop`; `scene-settings`, "The
/// backdrop is one source", design D3). The block's other settings, the angle and the blur, are
/// kept apart and survive every change of source.
public enum BackdropSource: Sendable, Equatable {
    /// No source: the scene shows the default backdrop.
    case unset
    /// One colour, `#rrggbb`.
    case colour(String)
    /// Two or more stops, each `#rrggbb`.
    case gradient([String])
    /// An image by its id on the host.
    case image(String)

    /// The kinds of source, as the segmented control offers them.
    public enum Kind: String, Sendable, CaseIterable, Identifiable {
        case unset, colour, gradient, image

        public var id: String { rawValue }
    }

    /// The source `block` holds, a scene's `backdrop`: unset where it holds none.
    public init(block: JSONValue?) {
        if let image = block?[Self.imageKey]?.stringValue {
            self = .image(image)
        } else if let stops = block?[Self.gradientKey]?.arrayValue {
            self = .gradient(stops.compactMap(\.stringValue))
        } else if let colour = block?[Self.colourKey]?.stringValue {
            self = .colour(colour)
        } else {
            self = .unset
        }
    }

    public var kind: Kind {
        switch self {
        case .unset: .unset
        case .colour: .colour
        case .gradient: .gradient
        case .image: .image
        }
    }

    /// This source switched to `kind`: what `memory` holds of that kind, else a start from what
    /// this shows, a colour from a gradient's first stop, a gradient from a colour and
    /// `background`, the scene's card colour, and either from `background` where there is nothing
    /// to start from. Nil for an image none was chosen for, which changes nothing until one is.
    public func switched(to kind: Kind, background: String, memory: BackdropMemory = .init())
        -> BackdropSource?
    {
        switch (kind, self) {
        case (.unset, _): .unset
        case (.colour, .colour), (.gradient, .gradient), (.image, .image): self
        case (.colour, .gradient(let stops)): .colour(memory.colour ?? stops.first ?? background)
        case (.colour, _): .colour(memory.colour ?? background)
        case (.gradient, .colour(let colour)): .gradient(memory.gradient ?? [colour, background])
        case (.gradient, _): .gradient(memory.gradient ?? [background, background])
        case (.image, _): memory.image.map(BackdropSource.image)
        }
    }

    /// `block`, a scene's `backdrop`, holding this source alone, its other settings kept but the
    /// angle, which the host takes only with a gradient: what the editor writes as the whole
    /// block. Unset writes nothing, so the block goes, blur and all: the host refuses a backdrop
    /// with no source (audio-vue `scene-backdrop`).
    public func written(over block: JSONValue?) -> [String: JSONValue] {
        guard self != .unset else { return [:] }
        var fields = block?.objectValue ?? [:]
        for key in Self.sourceKeys { fields[key] = nil }
        if kind != .gradient { fields[Self.angleKey] = nil }
        switch self {
        case .unset: break
        case .colour(let colour): fields[Self.colourKey] = .string(colour)
        case .gradient(let stops): fields[Self.gradientKey] = .array(stops.map(JSONValue.string))
        case .image(let id): fields[Self.imageKey] = .string(id)
        }
        return fields
    }

    // MARK: A gradient's stops

    /// The fewest stops a gradient holds (audio-vue `scene-backdrop`).
    public static let fewestStops = 2

    /// The gradient with a stop added after the last, as its colour; nil for any other source.
    public func addingStop() -> BackdropSource? {
        guard case .gradient(let stops) = self, let last = stops.last else { return nil }
        return .gradient(stops + [last])
    }

    /// The gradient without its stop at `index`; nil where that would leave too few stops or this
    /// is no gradient.
    public func removingStop(at index: Int) -> BackdropSource? {
        guard case .gradient(var stops) = self, stops.indices.contains(index),
            stops.count > Self.fewestStops
        else { return nil }
        stops.remove(at: index)
        return .gradient(stops)
    }

    /// The gradient with its stop at `index` moved `offset` places, -1 earlier or 1 later; nil
    /// where it would leave the list or this is no gradient.
    public func movingStop(at index: Int, by offset: Int) -> BackdropSource? {
        guard case .gradient(var stops) = self, stops.indices.contains(index),
            stops.indices.contains(index + offset)
        else { return nil }
        stops.swapAt(index, index + offset)
        return .gradient(stops)
    }

    /// The gradient with its stop at `index` set to `colour`; nil where this is no gradient.
    public func settingStop(at index: Int, to colour: String) -> BackdropSource? {
        guard case .gradient(var stops) = self, stops.indices.contains(index) else { return nil }
        stops[index] = colour
        return .gradient(stops)
    }

    /// `block`, a scene's `backdrop`, as a gradient with the stops and angle `standard` holds, the
    /// default look's backdrop, its other settings kept; nil where `standard` is no gradient or
    /// `block` already holds its stops and angle.
    public static func gradient(of standard: JSONValue?, over block: JSONValue?)
        -> [String: JSONValue]?
    {
        let source = BackdropSource(block: standard)
        guard source.kind == .gradient else { return nil }
        var fields = source.written(over: block)
        fields[angleKey] = standard?[angleKey]
        return fields == block?.objectValue ? nil : fields
    }

    /// The keys that name a source, which a backdrop holds one of.
    public static let sourceKeys = [colourKey, gradientKey, imageKey]
    static let colourKey = "color"
    static let gradientKey = "gradient"
    static let imageKey = "image"
    static let angleKey = "angle"
    static let blurKey = "blur"
}

/// What each backdrop source last held while the scene is edited, so choosing it again brings it
/// back: a gradient with its stops and angle, a colour, an image (`scene-settings`, design D3).
/// A backdrop holds one source, so a change of source takes the others out of the scene.
public struct BackdropMemory: Sendable, Equatable {
    public private(set) var colour: String?
    public private(set) var gradient: [String]?
    /// The remembered gradient's angle, nil where it declared none.
    public private(set) var angle: JSONValue?
    public private(set) var image: String?
    /// The blur the backdrop last held with a source, which None takes away with the block.
    public private(set) var blur: JSONValue?

    public init() {}

    /// Remembers the source `block`, a scene's `backdrop`, holds.
    public mutating func keep(_ block: JSONValue?) {
        let source = BackdropSource(block: block)
        if source != .unset { blur = block?[BackdropSource.blurKey] }
        switch source {
        case .unset: break
        case .colour(let held): colour = held
        case .gradient(let stops):
            gradient = stops
            angle = block?[BackdropSource.angleKey]
        case .image(let id): image = id
        }
    }
}

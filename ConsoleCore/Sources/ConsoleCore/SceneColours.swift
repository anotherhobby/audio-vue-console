/// The colours cards draw, as the host's schema declares them, and the lookup that resolves an
/// element's colour in a scene as the panel does (audio-vue `card-colours`, "A colour resolves by
/// lookup"; `scene-settings`, design D8). Every name and default is read; no rule is copied.
public struct SceneColours: Sendable, Equatable {
    /// One palette entry: a concrete colour a scene may set.
    public struct Swatch: Sendable, Equatable, Identifiable {
        public let name: String
        public let family: String
        public let label: String
        /// The colour where a scene's palette leaves it unset.
        public let defaultColour: HexColour

        public var id: String { name }
    }

    /// One thing cards draw, pointed at a swatch.
    public struct Element: Sendable, Equatable, Identifiable {
        public let name: String
        public let family: String
        public let label: String
        /// The swatch it is drawn in where a scene's `elements:` block leaves it unset.
        public let swatch: String

        public var id: String { name }
    }

    /// A block's settings that belong to one family, in declared order.
    public struct Family: Sendable, Equatable, Identifiable {
        public let name: String
        public let settings: [SettingDeclaration]

        public var id: String { name }
    }

    /// The swatches in declared order.
    public let swatches: [Swatch]
    /// The elements in declared order.
    public let elements: [Element]

    public static let none = SceneColours(swatches: [], elements: [])

    public init(swatches: [Swatch], elements: [Element]) {
        self.swatches = swatches
        self.elements = elements
    }

    /// The colours in `schema`, the body of `/v1/schema`: the swatches in `block.palette`'s
    /// order with the root's `x-swatches` families, and the elements in `block.elements`' order
    /// with the root's `x-elements` families and swatches. A decoded object keeps no order, so the
    /// blocks' `x-settings` give it.
    public init(schema: JSONValue) {
        let palette = SettingGroup(definition: schema["$defs"]?["block.palette"] ?? .null)
        let pointers = SettingGroup(definition: schema["$defs"]?["block.elements"] ?? .null)
        let swatches = palette.settings.compactMap { setting -> Swatch? in
            guard let family = schema["x-swatches"]?[setting.key]?["family"]?.stringValue,
                let colour = setting.defaultValue?.stringValue.flatMap(HexColour.init)
            else { return nil }
            return Swatch(
                name: setting.key, family: family, label: setting.label, defaultColour: colour)
        }
        let elements = pointers.settings.compactMap { setting -> Element? in
            let declared = schema["x-elements"]?[setting.key]
            guard let family = declared?["family"]?.stringValue,
                let swatch = declared?["swatch"]?.stringValue
            else { return nil }
            return Element(name: setting.key, family: family, label: setting.label, swatch: swatch)
        }
        self.init(swatches: swatches, elements: elements)
    }

    public func swatch(_ name: String) -> Swatch? {
        swatches.first { $0.name == name }
    }

    public func element(_ name: String) -> Element? {
        elements.first { $0.name == name }
    }

    /// The swatch a scene with `blocks` draws `element` in: the one its `elements:` block points
    /// it at, else the element's own.
    public func swatch(of element: String, in blocks: [String: JSONValue]) -> Swatch? {
        let pointed = blocks["elements"]?[element]?.stringValue ?? self.element(element)?.swatch
        return pointed.flatMap(swatch)
    }

    /// The colour `swatch` takes in a scene with `blocks`: its palette's, else the default.
    public func colour(ofSwatch swatch: String, in blocks: [String: JSONValue]) -> HexColour? {
        blocks["palette"]?[swatch]?.stringValue.flatMap(HexColour.init)
            ?? self.swatch(swatch)?.defaultColour
    }

    /// The colour a scene with `blocks` draws `element` in, where no card sets its own.
    public func colour(of element: String, in blocks: [String: JSONValue]) -> HexColour? {
        swatch(of: element, in: blocks).flatMap { colour(ofSwatch: $0.name, in: blocks) }
    }

    /// `settings`, a block's settings, grouped under the family each one's swatch or element
    /// belongs to, families in the order they first appear. Nil where `block` is neither the
    /// palette nor the elements.
    public func families(of settings: SettingGroup, in block: String) -> [Family]? {
        let family: (String) -> String?
        switch block {
        case "palette": family = { swatch($0)?.family }
        case "elements": family = { element($0)?.family }
        default: return nil
        }
        var order: [String] = []
        var members: [String: [SettingDeclaration]] = [:]
        for setting in settings.settings {
            let name = family(setting.key) ?? ""
            if members[name] == nil { order.append(name) }
            members[name, default: []].append(setting)
        }
        return order.map { Family(name: $0, settings: members[$0] ?? []) }
    }
}

/// The colour an unset card colour is drawn in, and where it comes from: the element it
/// overrides and the swatch the scene points that element at (`card-settings`, "A setting shows
/// the scene's value or the card's default").
public struct InheritedColour: Sendable, Equatable {
    public let element: SceneColours.Element
    public let swatch: SceneColours.Swatch
    public let colour: HexColour

    /// What the inspector says under the colour, such as "Uses Grid minor, in Line".
    public var caption: String {
        "Uses \(element.label), in \(swatch.label)"
    }
}

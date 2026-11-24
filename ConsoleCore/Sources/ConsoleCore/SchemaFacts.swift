/// What the app reads from the host's settings schema to lay scenes out: each card's minimum and
/// whether a user may place it, the categories the library groups cards under, the grid a scene
/// that declares none is laid out on, each card's settings, and the scene's blocks (audio-vue
/// `card-layout`, `card-categories`, `scene-grid`; `card-settings`, `scene-settings`).
public struct SchemaFacts: Sendable, Equatable {
    /// One card as the schema declares it.
    public struct Card: Sendable, Equatable, Identifiable {
        public let name: String
        /// Its minimum in cells, the same span on every scene (audio-vue `card-layout`).
        public let minimum: CellSize
        public let placeable: Bool
        /// The width over height a card keeps when its sizing is aspect-locked (`x-sizing` "aspect",
        /// with `x-aspect`), else nil: such a card is fitted and centred in whatever it is given.
        public let aspect: Double?

        public var id: String { name }

        public init(name: String, minimum: CellSize, placeable: Bool, aspect: Double? = nil) {
            self.name = name
            self.minimum = minimum
            self.placeable = placeable
            self.aspect = aspect
        }
    }

    /// A category the library lists cards under, as the panel declares it.
    public struct Category: Sendable, Equatable, Identifiable {
        public let id: String
        public let label: String
        /// Its cards by name, in the panel's order.
        public let cards: [String]

        public init(id: String, label: String, cards: [String]) {
            self.id = id
            self.label = label
            self.cards = cards
        }
    }

    /// One scene block and its settings, such as `colors`.
    public struct Block: Sendable, Equatable, Identifiable {
        /// The block's key in a scene document.
        public let name: String
        public let settings: SettingGroup

        public var id: String { name }

        public init(name: String, settings: SettingGroup) {
            self.name = name
            self.settings = settings
        }
    }

    /// One category's placeable cards, as the library shows them.
    public struct Shelf: Sendable, Equatable, Identifiable {
        public let category: Category
        public let cards: [Card]
        public var id: String { category.id }

        public init(category: Category, cards: [Card]) {
            self.category = category
            self.cards = cards
        }
    }

    public let cards: [String: Card]
    /// The categories in the panel's order.
    public let categories: [Category]
    /// Each card's settings in declared order, by card name: every card the schema declares,
    /// placeable or not.
    public let settings: [String: SettingGroup]
    /// Every block the scene declares, in the inspector's order: the blocks the app knows in
    /// `blockOrder`, then any other by name (`scene-settings`, design D2).
    public let blocks: [Block]
    /// The roles and scales cards draw in, and how a scene resolves them (design D8).
    public let colours: SceneColours
    /// The settings a scene holds as keys of its own, outside any block, such as its typeface, in
    /// the scene's declared order.
    public let sceneSettings: SettingGroup
    /// Each install block's settings, by the block's name, such as `display`: what a scene's
    /// block of the same name is read against where it leaves a setting unset.
    public let installSettings: [String: SettingGroup]
    /// The shape a scene must have to pass the host's validation, for its repair (`scene-repair`).
    public let shape: SceneShape
    /// The rates the panel runs at, `install.input.rate`'s, lowest first, or nil where the schema
    /// declares none.
    public let rates: [Int]?

    /// The blocks the app shows first, in this order.
    public static let blockOrder = [
        "backdrop", "glass", "grid", "display", "colors", "type", "case", "analysis",
    ]

    /// What the schema declares of a scene itself: its blocks, its colours and its own settings.
    public struct Scene: Sendable, Equatable {
        public let blocks: [Block]
        public let colours: SceneColours
        public let settings: SettingGroup
        /// The install's blocks' settings, by block name.
        public let installed: [String: SettingGroup]

        public static let none = Scene()

        public init(
            blocks: [Block] = [], colours: SceneColours = .none,
            settings: SettingGroup = SettingGroup([]), installed: [String: SettingGroup] = [:]
        ) {
            self.blocks = blocks
            self.colours = colours
            self.settings = settings
            self.installed = installed
        }
    }

    public init(
        cards: [String: Card], categories: [Category],
        settings: [String: SettingGroup] = [:], scene: Scene = .none, shape: SceneShape = .none,
        rates: [Int]? = nil
    ) {
        self.cards = cards
        self.shape = shape
        self.rates = rates
        self.categories = categories
        self.settings = settings
        blocks = scene.blocks
        colours = scene.colours
        sceneSettings = scene.settings
        installSettings = scene.installed
    }

    /// The facts in `schema`, the body of `/v1/schema`, or nil where it lacks the grid's defaults.
    public init?(schema: JSONValue) {
        guard let definitions = schema["$defs"]?.objectValue else { return nil }
        var cards: [String: Card] = [:]
        var settings: [String: SettingGroup] = [:]
        for (key, definition) in definitions where key.hasPrefix(Self.cardPrefix) {
            let name = String(key.dropFirst(Self.cardPrefix.count))
            settings[name] = SettingGroup(definition: definition)
            guard let minimum = Self.minimum(definition["x-min-cells"]) else { continue }
            let locked = definition["x-sizing"]?.stringValue == "aspect"
            cards[name] = Card(
                name: name, minimum: minimum,
                placeable: definition["x-placeable"]?.boolValue ?? false,
                aspect: locked ? definition["x-aspect"]?.numberValue : nil)
        }
        self.init(
            cards: cards, categories: Self.categories(schema["x-categories"]),
            settings: settings,
            scene: Scene(
                blocks: Self.blocks(definitions), colours: SceneColours(schema: schema),
                settings: Self.sceneSettings(definitions["scene"] ?? .null),
                installed: Self.installSettings(definitions)),
            shape: SceneShape(schema: schema), rates: Self.inputRates(schema))
    }

    /// What `declaration` takes while it is unset, where it declares the block its value comes
    /// from (audio-vue `x-inherits`): the setting of the same key there, as `scene`'s blocks or
    /// the install's `installed` blocks hold it, else that setting's default. Nil for a setting
    /// with a default of its own.
    public func inheritedValue(
        of declaration: SettingDeclaration, scene: [String: JSONValue],
        installed: [String: JSONValue]
    ) -> JSONValue? {
        guard let source = declaration.inherits else { return nil }
        let (held, declared): (JSONValue?, SettingGroup?) =
            switch source.document {
            case SettingDeclaration.Source.scene:
                (scene[source.block], block(source.block)?.settings)
            case SettingDeclaration.Source.install:
                (installed[source.block], installSettings[source.block])
            default: (nil, nil)
            }
        return held?[declaration.key] ?? declared?[declaration.key]?.defaultValue
    }

    /// The block `name`, or nil where the scene declares none by it.
    public func block(_ name: String) -> Block? {
        blocks.first { $0.name == name }
    }

    /// The placeable cards under their categories, both in the panel's order, leaving out a
    /// category with none.
    public var library: [Shelf] {
        categories.compactMap { category in
            let placeable = category.cards.compactMap { cards[$0] }.filter(\.placeable)
            return placeable.isEmpty ? nil : Shelf(category: category, cards: placeable)
        }
    }

    /// The cards a user may place, in the library's order.
    public var placeable: [Card] {
        library.flatMap(\.cards)
    }

    /// The minimum of every card the schema declares, by name.
    public var minimums: [String: CellSize] {
        cards.mapValues(\.minimum)
    }

    /// The capture rates `install.input.rate` takes, in Hz, lowest first: the rates the host
    /// calibrates at, which the Input section offers and an every-rate pass runs. Nil where the
    /// schema declares none (`capture-input`, design D1).
    public static func inputRates(_ schema: JSONValue) -> [Int]? {
        let rate = schema["$defs"]?["install.input"]?["properties"]?["rate"]
        guard let choices = rate?["enum"]?.arrayValue else { return nil }
        let rates = choices.compactMap(\.intValue).sorted()
        return rates.isEmpty ? nil : rates
    }

    /// The capture formats `install.input.fmt` takes, as ALSA names them, in the order the schema
    /// declares them. Nil where the schema declares none (`capture-input`, design D1).
    public static func inputFormats(_ schema: JSONValue) -> [String]? {
        let format = schema["$defs"]?["install.input"]?["properties"]?["fmt"]
        guard let choices = format?["enum"]?.arrayValue else { return nil }
        let formats = choices.compactMap(\.stringValue)
        return formats.isEmpty ? nil : formats
    }

    /// The capture format `install.input.fmt` takes where the block leaves it unset, or nil where
    /// the schema declares no default.
    public static func inputFormatDefault(_ schema: JSONValue) -> String? {
        schema["$defs"]?["install.input"]?["properties"]?["fmt"]?["default"]?.stringValue
    }

    /// The channel pair `install.input.pair` takes where the block leaves it unset, or nil where
    /// the schema declares no default (`input-channels`).
    public static func inputPairDefault(_ schema: JSONValue) -> [Int]? {
        let pair = schema["$defs"]?["install.input"]?["properties"]?["pair"]?["default"]
        return pair?.arrayValue.map { $0.compactMap(\.intValue) }
    }

    private static let cardPrefix = "card."
    private static let blockReference = "#/$defs/block."

    /// The blocks `scene`'s properties refer to, each read from its definition, in the
    /// inspector's order.
    private static func installSettings(_ definitions: [String: JSONValue])
        -> [String: SettingGroup]
    {
        var groups: [String: SettingGroup] = [:]
        for (key, definition) in definitions where key.hasPrefix(installPrefix) {
            groups[String(key.dropFirst(installPrefix.count))] = SettingGroup(
                definition: definition)
        }
        return groups
    }

    private static let installPrefix = "install."

    private static func blocks(_ definitions: [String: JSONValue]) -> [Block] {
        let properties = definitions["scene"]?["properties"]?.objectValue ?? [:]
        let names = properties.values.compactMap { property -> String? in
            guard let reference = property["$ref"]?.stringValue,
                reference.hasPrefix(blockReference)
            else { return nil }
            return String(reference.dropFirst(blockReference.count))
        }
        let rank = { (name: String) in blockOrder.firstIndex(of: name) ?? blockOrder.count }
        return names.sorted { (rank($0), $0) < (rank($1), $1) }.compactMap { name in
            definitions["block.\(name)"].map {
                Block(name: name, settings: SettingGroup(definition: $0))
            }
        }
    }

    /// The settings `scene`, the scene's definition, declares as keys of its own: each property
    /// carrying a label, in the object's sorted order, since the scene lists no order of its own.
    private static func sceneSettings(_ scene: JSONValue) -> SettingGroup {
        let properties = scene["properties"]?.objectValue ?? [:]
        return SettingGroup(
            properties.keys.sorted().compactMap { key in
                properties[key].flatMap { property in
                    property["x-label"] == nil
                        ? nil : SettingDeclaration(key: key, property: property)
                }
            })
    }

    /// The root's `x-categories`: `{id, label, cards}` in the panel's order.
    private static func categories(_ value: JSONValue?) -> [Category] {
        (value?.arrayValue ?? []).compactMap { entry in
            guard let id = entry["id"]?.stringValue, let label = entry["label"]?.stringValue
            else { return nil }
            let cards = (entry["cards"]?.arrayValue ?? []).compactMap(\.stringValue)
            return Category(id: id, label: label, cards: cards)
        }
    }

    private static func minimum(_ value: JSONValue?) -> CellSize? {
        guard let pair = value?.arrayValue, pair.count == 2,
            let cols = pair[0].intValue, let rows = pair[1].intValue
        else { return nil }
        return CellSize(cols: cols, rows: rows)
    }
}

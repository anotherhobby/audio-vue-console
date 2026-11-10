/// What the app reads from the host's settings schema to lay scenes out: each card's minimum and
/// whether a user may place it, the categories the library groups cards under, the grid a scene
/// that declares none is laid out on, and each card's settings (audio-vue `card-layout`,
/// `card-categories`, `scene-grid`; `card-settings`).
public struct SchemaFacts: Sendable, Equatable {
    /// One card as the schema declares it.
    public struct Card: Sendable, Equatable, Identifiable {
        public let name: String
        /// Its minimum on a grid `referenceRows` tall.
        public let minimum: CellSize
        public let placeable: Bool

        public var id: String { name }

        public init(name: String, minimum: CellSize, placeable: Bool) {
            self.name = name
            self.minimum = minimum
            self.placeable = placeable
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

    /// The rows a card's declared minimum is counted on (audio-vue `card-layout`).
    public static let referenceRows = 36

    public let cards: [String: Card]
    /// The categories in the panel's order.
    public let categories: [Category]
    public let defaultGrid: CellSize
    /// Each card's settings in declared order, by card name: every card the schema declares,
    /// placeable or not.
    public let settings: [String: SettingGroup]

    public init(
        cards: [String: Card], categories: [Category], defaultGrid: CellSize,
        settings: [String: SettingGroup] = [:]
    ) {
        self.cards = cards
        self.categories = categories
        self.defaultGrid = defaultGrid
        self.settings = settings
    }

    /// The facts in `schema`, the body of `/v1/schema`, or nil where it lacks the grid's defaults.
    public init?(schema: JSONValue) {
        let definitions = schema["$defs"]?.objectValue ?? [:]
        guard let grid = definitions["block.grid"]?["properties"],
            let cols = grid["cols"]?["default"]?.intValue,
            let rows = grid["rows"]?["default"]?.intValue
        else { return nil }
        var cards: [String: Card] = [:]
        var settings: [String: SettingGroup] = [:]
        for (key, definition) in definitions where key.hasPrefix(Self.cardPrefix) {
            let name = String(key.dropFirst(Self.cardPrefix.count))
            settings[name] = SettingGroup(definition: definition)
            guard let minimum = Self.minimum(definition["x-min-cells"]) else { continue }
            cards[name] = Card(
                name: name, minimum: minimum,
                placeable: definition["x-placeable"]?.boolValue ?? false)
        }
        self.init(
            cards: cards, categories: Self.categories(schema["x-categories"]),
            defaultGrid: CellSize(cols: cols, rows: rows), settings: settings)
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

    /// The minimum of every card the schema declares, scaled to a grid `rows` tall.
    public func minimums(forRows rows: Int) -> [String: CellSize] {
        cards.mapValues { Self.scaled($0.minimum, toRows: rows) }
    }

    /// `minimum` on a grid `rows` tall: each side scaled by the rows and rounded up, as audio-vue's
    /// `layout.min_span` does.
    public static func scaled(_ minimum: CellSize, toRows rows: Int) -> CellSize {
        CellSize(cols: roundedUp(minimum.cols * rows), rows: roundedUp(minimum.rows * rows))
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

    private static let cardPrefix = "card."

    private static func roundedUp(_ cellsTimesRows: Int) -> Int {
        (cellsTimesRows + referenceRows - 1) / referenceRows
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

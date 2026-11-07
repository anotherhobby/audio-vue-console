/// What the app reads from the host's settings schema to lay scenes out: each card's minimum and
/// whether a user may place it, and the grid a scene that declares none is laid out on (audio-vue
/// `card-layout`, `scene-grid`).
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

    /// The rows a card's declared minimum is counted on (audio-vue `card-layout`).
    public static let referenceRows = 36

    public let cards: [String: Card]
    public let defaultGrid: CellSize

    public init(cards: [String: Card], defaultGrid: CellSize) {
        self.cards = cards
        self.defaultGrid = defaultGrid
    }

    /// The facts in `schema`, the body of `/v1/schema`, or nil where it lacks the grid's defaults.
    public init?(schema: JSONValue) {
        let definitions = schema["$defs"]?.objectValue ?? [:]
        guard let grid = definitions["block.grid"]?["properties"],
            let cols = grid["cols"]?["default"]?.intValue,
            let rows = grid["rows"]?["default"]?.intValue
        else { return nil }
        var cards: [String: Card] = [:]
        for (key, definition) in definitions where key.hasPrefix(Self.cardPrefix) {
            let name = String(key.dropFirst(Self.cardPrefix.count))
            guard let minimum = Self.minimum(definition["x-min-cells"]) else { continue }
            cards[name] = Card(
                name: name, minimum: minimum,
                placeable: definition["x-placeable"]?.boolValue ?? false)
        }
        self.init(cards: cards, defaultGrid: CellSize(cols: cols, rows: rows))
    }

    /// The cards a user may place, by name.
    public var placeable: [Card] {
        cards.values.filter(\.placeable).sorted { $0.name < $1.name }
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

    private static let cardPrefix = "card."

    private static func roundedUp(_ cellsTimesRows: Int) -> Int {
        (cellsTimesRows + referenceRows - 1) / referenceRows
    }

    private static func minimum(_ value: JSONValue?) -> CellSize? {
        guard let pair = value?.arrayValue, pair.count == 2,
            let cols = pair[0].intValue, let rows = pair[1].intValue
        else { return nil }
        return CellSize(cols: cols, rows: rows)
    }
}

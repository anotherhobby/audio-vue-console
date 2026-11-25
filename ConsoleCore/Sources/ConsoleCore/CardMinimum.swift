/// A card's smallest sizes as the render helper answers them (`card-minimum`, design D1): for each
/// width, the least height at which the card is drawn whole, and the least at which it shows its
/// reading. A width the helper leaves out has no such height.
public struct CardMinimum: Sendable, Equatable {
    /// Rows by columns: the least height at which the card drops nothing its settings ask for.
    public let whole: [Int: Int]
    /// Rows by columns: the least height at which the card shows its reading, not Too Small.
    public let readable: [Int: Int]

    public init(whole: [Int: Int], readable: [Int: Int]) {
        self.whole = whole
        self.readable = readable
    }

    /// The answer to a `minimum` request, from its header, or nil where it refused or failed or
    /// does not decode.
    public init?(answer header: JSONValue) {
        guard header["ok"] == .bool(true), let whole = Self.sizes(header["whole"]),
            let readable = Self.sizes(header["readable"])
        else { return nil }
        self.init(whole: whole, readable: readable)
    }

    /// The size a card is shown and dropped at: the whole size with the fewest cells, the narrower
    /// on a tie; else the readable size by the same rule; else nil, where the declared minimum
    /// stands in (`card-minimum`, "A card's whole size is the smallest whole one").
    public var wholeSize: CellSize? {
        Self.smallest(whole) ?? Self.smallest(readable)
    }

    /// The least rows at each width, which a resize stops at.
    public var floor: MinimumFloor { .answered(readable) }

    private static func smallest(_ sizes: [Int: Int]) -> CellSize? {
        sizes.map { CellSize(cols: $0.key, rows: $0.value) }.min { first, second in
            (first.cols * first.rows, first.cols) < (second.cols * second.rows, second.cols)
        }
    }

    /// `[[cols, rows], ...]` as rows by columns, or nil where any entry is not two whole numbers.
    private static func sizes(_ value: JSONValue?) -> [Int: Int]? {
        guard let entries = value?.arrayValue else { return nil }
        var sizes: [Int: Int] = [:]
        for entry in entries {
            guard let pair = entry.arrayValue, pair.count == 2, let cols = pair[0].intValue,
                let rows = pair[1].intValue
            else { return nil }
            sizes[cols] = rows
        }
        return sizes
    }
}

/// The least rows a card may have at each width it may take (`card-minimum`, "The readable floor
/// depends on the width"): from the helper's answer, or, until one is held, the declared minimum
/// at every width from its columns.
public enum MinimumFloor: Sendable, Equatable {
    case declared(CellSize)
    case answered([Int: Int])

    /// The least rows at `cols` columns, or nil where the card may not be that wide.
    public func rows(at cols: Int) -> Int? {
        switch self {
        case .declared(let size): cols >= size.cols ? size.rows : nil
        case .answered(let rows): rows[cols]
        }
    }

    /// No floor beyond a single cell: what a card with no declared minimum takes.
    public static let oneCell = MinimumFloor.declared(.oneCell)
}

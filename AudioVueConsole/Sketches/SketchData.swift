import Foundation

/// Made-up panels and real scene layouts for the UI sketches, loaded from `sketch.json`.
/// Throwaway: the panel client and the canvas spike replace this.
struct SketchData: Decodable {
    let panels: [SketchPanel]
    let scenes: [SketchScene]

    static let shared: SketchData = load()

    private static func load() -> SketchData {
        guard let url = Bundle.main.url(forResource: "sketch", withExtension: "json") else {
            return SketchData(panels: [], scenes: [])
        }
        do {
            return try JSONDecoder().decode(SketchData.self, from: Data(contentsOf: url))
        } catch {
            return SketchData(panels: [], scenes: [])
        }
    }
}

struct SketchPanel: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let condition: String
    let widthPx: Int
    let heightPx: Int
    let scene: String
    let calibratedDaysAgo: Int

    var isUp: Bool { condition == "up" }
    var aspect: Double { Double(widthPx) / Double(heightPx) }
    var shapeName: String { SketchShape.name(width: widthPx, height: heightPx) }

    func fits(_ scene: SketchScene) -> Bool {
        SketchShape.matches(aspect, scene.aspect)
    }
}

struct SketchScene: Decodable, Identifiable, Hashable {
    let spec: String
    let name: String
    let builtIn: Bool
    let cols: Int
    let rows: Int
    let cards: [SketchCard]

    var id: String { spec }
    var aspect: Double { Double(cols) / Double(rows) }
    var shapeName: String { SketchShape.name(width: cols, height: rows) }

    /// Each declared group's bounding cells, which the host requires its members to tile.
    var groupBounds: [String: SketchCells] {
        Dictionary(grouping: cards.filter { $0.group != nil }) { $0.group ?? "" }
            .mapValues { SketchCells(enclosing: $0.map(\.cells)) }
    }
}

struct SketchCard: Decodable, Identifiable, Hashable {
    let card: String
    let col: Int
    let row: Int
    let colspan: Int
    let rowspan: Int
    let group: String?

    var id: String { "\(card)@\(col),\(row)" }
    var title: String { card.replacingOccurrences(of: "_", with: " ") }
    var cells: SketchCells { SketchCells(col: col, row: row, cols: colspan, rows: rowspan) }
}

/// One kind of card for the library, at the size it first has in the scenes. The host will give
/// the roster and render each tile; until then the sketch gathers them from the scenes.
struct SketchCardKind: Identifiable, Hashable {
    let card: String
    let cols: Int
    let rows: Int

    var id: String { card }
    var title: String { card.replacingOccurrences(of: "_", with: " ") }
    var aspect: Double { Double(cols) / Double(rows) }

    static func roster(from scenes: [SketchScene]) -> [SketchCardKind] {
        var kinds: [String: SketchCardKind] = [:]
        for card in scenes.flatMap(\.cards) where kinds[card.card] == nil {
            kinds[card.card] = SketchCardKind(
                card: card.card, cols: card.colspan, rows: card.rowspan)
        }
        return kinds.values.sorted { $0.card < $1.card }
    }
}

/// A block of grid cells, row 0 at the top as in the host's scenes.
struct SketchCells: Hashable {
    let col: Int
    let row: Int
    let cols: Int
    let rows: Int

    init(col: Int, row: Int, cols: Int, rows: Int) {
        self.col = col
        self.row = row
        self.cols = cols
        self.rows = rows
    }

    init(enclosing blocks: [SketchCells]) {
        let left = blocks.map(\.col).min() ?? 0
        let top = blocks.map(\.row).min() ?? 0
        let right = blocks.map { $0.col + $0.cols }.max() ?? left
        let bottom = blocks.map { $0.row + $0.rows }.max() ?? top
        self.init(col: left, row: top, cols: right - left, rows: bottom - top)
    }
}

enum SketchShape {
    static let tolerance = 0.01

    static func matches(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) < tolerance
    }

    /// `1920 x 720` is `8:3`.
    static func name(width: Int, height: Int) -> String {
        let divisor = gcd(width, height)
        guard divisor > 0 else { return "?" }
        return "\(width / divisor):\(height / divisor)"
    }

    private static func gcd(_ lhs: Int, _ rhs: Int) -> Int {
        rhs == 0 ? lhs : gcd(rhs, lhs % rhs)
    }
}

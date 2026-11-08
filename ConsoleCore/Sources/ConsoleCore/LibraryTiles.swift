import CoreGraphics
import Foundation
import Observation

/// The card library's tiles, each a card's plate as the helper draws it alone, at its minimum at
/// the open scene's top-left corner, in that scene's settings (`scene-rendering`, "A library tile
/// is the card's plate as the helper draws it"; `library-render` design D1, D3 and D6). One set is
/// kept, for the settings it was drawn in, so scenes that share their settings share their tiles
/// and no edit to a scene's cards draws one again.
@MainActor @Observable
public final class LibraryTiles {
    /// One card's tile: the plate the helper drew, and the image the library shows.
    public struct Tile: Sendable {
        public let layer: RenderedLayer
        /// The plate stacked over the patch of the backdrop under it, or the plate alone.
        public let image: CGImage

        /// `layer` over `backdrop` where there is one and the two can be stacked, else alone.
        public init(layer: RenderedLayer, over backdrop: RenderedLayer?) {
            self.layer = layer
            image = backdrop.flatMap { Thumbnail.tile(plate: layer, over: $0) } ?? layer.image
        }

        /// The cards that cannot show their reading at the card's minimum, by name.
        public var unfit: [String] { layer.unfit }
    }

    /// The settings tiles are drawn in: the scene's doc with its cards and name removed, and its
    /// grid, which a doc declaring none takes from the schema.
    struct Key: Hashable {
        let settings: JSONValue
        let grid: CellSize

        init(_ laidOut: LaidOutScene) {
            var fields = laidOut.document.doc.objectValue ?? [:]
            fields["cards"] = nil
            fields["name"] = nil
            settings = .object(fields)
            grid = laidOut.layout.grid
        }
    }

    /// Each card's tile, by card name.
    public private(set) var tiles: [String: Tile] = [:]
    /// The canvas's backdrop layer, which each tile is stacked over.
    public private(set) var backdrop: RenderedLayer?
    private var key: Key?
    /// The cards asked for under `key`, answered or not.
    private var asked: Set<String> = []

    public init() {}

    /// Draws a tile for each of `cards` in `laidOut`'s settings through `queue`, all at once in the
    /// library's lane, skipping those already asked for and the cards `drift` boxes, whose tiles are
    /// dropped. Tiles drawn for other settings, and the backdrop with them, are dropped first. The
    /// caller draws only where the code is the panel's, or differs without shared code (design D4).
    public func draw(
        for laidOut: LaidOutScene, cards: [SchemaFacts.Card], drift: CardDrift?,
        context: RenderContext, through queue: RenderQueue
    ) async {
        let key = Key(laidOut)
        if key != self.key {
            self.key = key
            tiles = [:]
            backdrop = nil
            asked = []
        }
        // A card whose code has come to differ loses the tile drawn before.
        let boxed = Set(cards.map(\.name).filter { drift?.boxes($0) ?? false })
        for name in boxed { tiles[name] = nil }
        asked.subtract(boxed)
        let wanted = cards.filter { !asked.contains($0.name) && !boxed.contains($0.name) }
        asked.formUnion(wanted.map(\.name))
        let requests = wanted.compactMap { card in
            Self.request(
                for: laidOut, card: card.name,
                minimum: SchemaFacts.scaled(card.minimum, toRows: key.grid.rows), context: context
            ).map { (card: card.name, message: $0.message) }
        }
        await withTaskGroup(of: Void.self) { group in
            for (card, message) in requests {
                group.addTask { await self.ask(message, for: card, drawnIn: key, through: queue) }
            }
        }
    }

    /// Sends `card`'s tile request in the library's lane, and keeps what it draws.
    private func ask(
        _ message: JSONValue, for card: String, drawnIn key: Key, through queue: RenderQueue
    ) async {
        let result = await queue.submit(message, lane: .library, key: "tile:\(card)")
        take(result, for: card, drawnIn: key)
    }

    /// Stacks every tile held over `backdrop`, the canvas's, with no request.
    public func show(backdrop: RenderedLayer) {
        guard self.backdrop?.image !== backdrop.image else { return }
        self.backdrop = backdrop
        tiles = tiles.mapValues { Tile(layer: $0.layer, over: backdrop) }
    }

    /// Forgets every tile, as when another panel is shown.
    public func forget() {
        tiles = [:]
        backdrop = nil
        key = nil
        asked = []
    }

    /// A tile's request: a copy of `laidOut` holding only `card` at `minimum` at the grid's
    /// top-left corner, naming its one plate and no backdrop, or nil where the card is off the grid.
    static func request(
        for laidOut: LaidOutScene, card: String, minimum: CellSize, context: RenderContext
    ) -> RenderRequest? {
        let cells = CellRect(col: 0, row: 0, cols: minimum.cols, rows: minimum.rows)
        let layout: SceneLayout
        do throws(LayoutRefusal) {
            layout = try SceneLayout(
                grid: laidOut.layout.grid, cards: [LayoutCard(kind: card, cells: cells)])
        } catch {
            return nil
        }
        return RenderRequest(
            doc: laidOut.doc(for: layout), builtIn: laidOut.document.builtIn, context: context,
            plates: [0], backdrop: false)
    }

    /// Keeps a drawn plate as `card`'s tile, unless the settings changed while it was drawn. A
    /// replaced, refused or failed request leaves the card a box.
    private func take(
        _ result: Result<HelperAnswer, RenderFailure>?, for card: String, drawnIn key: Key
    ) {
        guard key == self.key, asked.contains(card), case .success(let answer)? = result else {
            return
        }
        let layers: [RenderedLayer]
        do throws(RenderFailure) {
            // The one placement's id is never read: a tile is known by its card's name.
            layers = try RenderedLayer.layers(of: answer, cardIDs: [UUID()])
        } catch {
            return
        }
        guard let plate = layers.first(where: { $0.kind == .plate }) else { return }
        tiles[card] = Tile(layer: plate, over: backdrop)
    }
}

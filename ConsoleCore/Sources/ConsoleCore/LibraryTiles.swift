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

    /// The settings tiles are drawn in: the scene's doc as edited with its cards and name removed
    /// (`scene-settings`, design D6). Every scene of a panel is on the panel's grid.
    struct Key: Hashable {
        let settings: JSONValue

        init(_ laidOut: LaidOutScene, _ content: SceneContent) {
            var fields = laidOut.doc(for: content).objectValue ?? [:]
            fields["cards"] = nil
            fields["name"] = nil
            settings = .object(fields)
        }
    }

    /// What tiles are drawn from, the same for every scene of a panel: the library's cards, the
    /// cards `drift` boxes, what every request carries, and the queue.
    public struct Source {
        public let cards: [SchemaFacts.Card]
        public let drift: CardDrift?
        public let context: RenderContext
        public let queue: RenderQueue

        public init(
            cards: [SchemaFacts.Card], drift: CardDrift?, context: RenderContext,
            queue: RenderQueue
        ) {
            self.cards = cards
            self.drift = drift
            self.context = context
            self.queue = queue
        }
    }

    /// The tiles drawn in one scene's settings.
    private struct TileSet {
        var tiles: [String: Tile] = [:]
        var backdrop: RenderedLayer?
        /// The cards asked for while the scene is shown, answered or not.
        var asked: Set<String> = []
        /// The cards asked for ahead of the scene being shown.
        var ahead: Set<String> = []
        var askedBackdrop = false

        /// The cards of `source` to ask for at `pace`, noted as asked for: those with no tile,
        /// not asked for already, and not boxed by the drift, whose tiles drawn before are
        /// dropped.
        mutating func claim(_ source: Source, _ pace: Pace) -> [SchemaFacts.Card] {
            let boxed = Set(source.cards.map(\.name).filter { source.drift?.boxes($0) ?? false })
            for name in boxed { tiles[name] = nil }
            asked.subtract(boxed)
            ahead.subtract(boxed)
            let wanted = source.cards.filter { card in
                tiles[card.name] == nil && !boxed.contains(card.name)
                    && !asked.contains(card.name)
                    && !(pace == .ahead && ahead.contains(card.name))
            }
            if pace == .shown {
                asked.formUnion(wanted.map(\.name))
            } else {
                ahead.formUnion(wanted.map(\.name))
            }
            return wanted
        }
    }

    /// One card's tile request.
    private struct TileRequest: Sendable {
        let card: String
        let request: RenderRequest
    }

    /// When a set's tiles are wanted: at once for the scene shown, in the library's lane, or
    /// ahead of any scene being opened, behind the thumbnails.
    private enum Pace {
        case shown, ahead

        var lane: RenderQueue.Lane { self == .shown ? .library : .thumbnails }
    }

    /// How many scenes' tiles are kept, the least recently drawn dropped first.
    public static let kept = 12

    /// Each card's tile in the shown scene's settings, by card name.
    public var tiles: [String: Tile] { key.flatMap { sets[$0]?.tiles } ?? [:] }
    /// The shown scene's backdrop layer, which each tile is stacked over.
    public var backdrop: RenderedLayer? { key.flatMap { sets[$0]?.backdrop } }
    /// The settings of the scene shown.
    private var key: Key?
    private var sets: [Key: TileSet] = [:]
    /// The settings tiles are held for, the least recently drawn first.
    private var recent: [Key] = []

    public init() {}

    /// Shows the tiles of `draft`'s settings, the scene as edited, drawing those not yet held
    /// all at once in the library's lane, skipping those already asked for and the cards the
    /// drift boxes, whose tiles are dropped. Tiles held for other settings are kept, so a scene
    /// opened again, or one drawn ahead, shows its tiles with no request. The caller draws only
    /// where the code is the panel's, or differs without shared code (design D4).
    public func draw(for draft: Draft, from source: Source) async {
        key = Key(draft.laidOut, draft.content)
        await fill(draft, .shown, from: source)
    }

    /// Draws the tiles of `draft`'s settings ahead of its scene being opened, behind the
    /// thumbnails, with its backdrop, leaving the tiles shown as they are.
    public func prepare(for draft: Draft, from source: Source) async {
        await fill(draft, .ahead, from: source)
    }

    private func fill(_ draft: Draft, _ pace: Pace, from source: Source) async {
        let (laidOut, content) = (draft.laidOut, draft.content)
        let key = Key(laidOut, content)
        touch(key)
        var set = sets[key] ?? TileSet()
        let requests = set.claim(source, pace).compactMap { card in
            Self.request(
                for: laidOut, as: content, card: card.name, minimum: card.minimum,
                context: source.context
            ).map { TileRequest(card: card.name, request: $0) }
        }
        // The canvas gives a shown scene's backdrop, unless it holds no card to draw.
        let wantsBackdrop =
            set.backdrop == nil && !set.askedBackdrop
            && (pace == .ahead || content.layout.cards.isEmpty)
        let around = wantsBackdrop ? requests.first?.request ?? Self.any(draft, from: source) : nil
        if around != nil { set.askedBackdrop = true }
        sets[key] = set
        let backdrop = around.map {
            RenderRequest(
                doc: $0.doc, builtIn: $0.builtIn, context: source.context, plates: [],
                backdrop: true)
        }
        await send(requests, backdrop: backdrop, for: key, pace, through: source.queue)
    }

    /// Sends each tile's request and the backdrop's, where there is one, at `pace`, and keeps
    /// what they draw for `key`'s settings. A request made ahead is named for its settings, so
    /// no other scene's replaces it.
    private func send(
        _ requests: [TileRequest], backdrop: RenderRequest?, for key: Key, _ pace: Pace,
        through queue: RenderQueue
    ) async {
        let tag = pace == .shown ? "" : "ahead:\(key.hashValue):"
        await withTaskGroup(of: Void.self) { group in
            for tile in requests {
                group.addTask {
                    let result = await queue.submit(
                        tile.request.message, lane: pace.lane, key: "\(tag)tile:\(tile.card)")
                    await self.take(result, for: tile.card, drawnIn: key)
                }
            }
            if let backdrop {
                group.addTask {
                    let result = await queue.submit(
                        backdrop.message, lane: pace.lane, key: "\(tag)tile-backdrop")
                    await self.takeBackdrop(result, drawnIn: key)
                }
            }
        }
    }

    /// A tile's request for the first card of the library that fits `draft`'s grid, which a
    /// request for the backdrop alone is made around: a scene with no cards is refused.
    private static func any(_ draft: Draft, from source: Source) -> RenderRequest? {
        source.cards.lazy.compactMap { card in
            request(
                for: draft.laidOut, as: draft.content, card: card.name, minimum: card.minimum,
                context: source.context)
        }.first
    }

    /// Notes `key` as the settings drawn last, and drops the tiles of those drawn longest ago
    /// beyond `kept`, never the shown scene's.
    private func touch(_ key: Key) {
        recent.removeAll { $0 == key }
        recent.append(key)
        while recent.count > Self.kept, let old = recent.first(where: { $0 != self.key }) {
            recent.removeAll { $0 == old }
            sets[old] = nil
        }
    }

    /// Keeps a drawn backdrop for `key`'s tiles, stacking them over it.
    private func takeBackdrop(_ result: Result<HelperAnswer, RenderFailure>?, drawnIn key: Key) {
        guard case .success(let answer)? = result, sets[key]?.backdrop == nil else { return }
        do throws(RenderFailure) {
            let layers = try RenderedLayer.layers(of: answer, cardIDs: [])
            if let drawn = layers.first(where: { $0.kind == .backdrop }) {
                stack(key, over: drawn)
            }
        } catch {
            return
        }
    }

    /// Stacks every tile held for the shown scene over `backdrop`, the canvas's, with no request.
    public func show(backdrop: RenderedLayer) {
        guard let key, sets[key]?.backdrop?.image !== backdrop.image else { return }
        stack(key, over: backdrop)
    }

    private func stack(_ key: Key, over backdrop: RenderedLayer) {
        guard var set = sets[key] else { return }
        set.backdrop = backdrop
        set.tiles = set.tiles.mapValues { Tile(layer: $0.layer, over: backdrop) }
        sets[key] = set
    }

    /// Forgets every tile, as when another panel is shown.
    public func forget() {
        sets = [:]
        recent = []
        key = nil
    }

    /// A tile's request: `content`, an edit of `laidOut`, holding only `card` at `minimum` at the
    /// grid's top-left corner, naming its one plate and no backdrop, or nil where the card is off
    /// the grid.
    static func request(
        for laidOut: LaidOutScene, as content: SceneContent, card: String, minimum: CellSize,
        context: RenderContext
    ) -> RenderRequest? {
        let cells = CellRect(col: 0, row: 0, cols: minimum.cols, rows: minimum.rows)
        let layout: SceneLayout
        do throws(LayoutRefusal) {
            layout = try SceneLayout(
                grid: laidOut.panel, cards: [LayoutCard(kind: card, cells: cells)])
        } catch {
            return nil
        }
        return RenderRequest(
            doc: laidOut.doc(for: content.with(layout: layout)), builtIn: laidOut.document.builtIn,
            context: context, plates: [0], backdrop: false)
    }

    /// Keeps a drawn plate as `card`'s tile in `key`'s settings, while they are held and the card
    /// is still asked for. A request replaced in the queue may be asked again; a refused or
    /// failed one leaves the card a box.
    private func take(
        _ result: Result<HelperAnswer, RenderFailure>?, for card: String, drawnIn key: Key
    ) {
        guard var set = sets[key] else { return }
        defer { sets[key] = set }
        guard let result else {
            set.asked.remove(card)
            return
        }
        guard set.asked.contains(card) || set.ahead.contains(card),
            case .success(let answer) = result
        else { return }
        let layers: [RenderedLayer]
        do throws(RenderFailure) {
            // The one placement's id is never read: a tile is known by its card's name.
            layers = try RenderedLayer.layers(of: answer, cardIDs: [UUID()])
        } catch {
            return
        }
        guard let plate = layers.first(where: { $0.kind == .plate }) else { return }
        set.tiles[card] = Tile(layer: plate, over: set.backdrop)
    }
}

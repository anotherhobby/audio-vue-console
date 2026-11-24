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
        /// The size the plate was drawn at, in cells of the panel's grid.
        public let size: CellSize
        /// The plate stacked over the patch of the backdrop under it, or the plate alone.
        public let image: CGImage

        /// `layer`, drawn at `size`, over `backdrop` where there is one and the two can be stacked, else alone.
        public init(layer: RenderedLayer, size: CellSize, over backdrop: RenderedLayer?) {
            self.layer = layer
            self.size = size
            image = backdrop.flatMap { Thumbnail.tile(plate: layer, over: $0) } ?? layer.image
        }

        /// The cards that cannot show their reading at the card's minimum, by name.
        public var unfit: [String] { layer.unfit }
    }

    /// The settings tiles are drawn in: the scene's doc as edited with its cards, its name and the
    /// blocks no render reads removed (`scene-settings`, design D6; `track-native-logo` design D7).
    /// Every scene of a panel is on the panel's grid.
    struct Key: Hashable {
        let settings: JSONValue

        init(_ laidOut: LaidOutScene, _ content: SceneContent) {
            var fields = laidOut.doc(for: content).objectValue ?? [:]
            for unread in ["cards", "name"] + RenderRequest.undrawnBlocks { fields[unread] = nil }
            settings = .object(fields)
        }
    }

    /// What tiles are drawn from, the same for every scene of a panel: the library's cards, the
    /// cards `drift` boxes, what every request carries, and the queue.
    public struct Source: Sendable {
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
    struct TileSet {
        var tiles: [String: Tile] = [:]
        /// Each set-up card's tile, by name (`library-setup`).
        var setups: [String: SetupTile] = [:]
        /// The settings each card's set-up tile was last asked for in, by name.
        var wantedSetups: [String: [String: JSONValue]] = [:]
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

    /// The sizes a tile is tried at: its declared minimum, grown by whole cells. An aspect-locked card
    /// grows in its declared aspect, so its tile keeps the card's shape (`scene-rendering`).
    @MainActor
    enum Ladder {
        /// The size `step` cells up the ladder from `card`'s minimum.
        static func size(_ card: SchemaFacts.Card, step: Int) -> CellSize {
            guard let aspect = card.aspect, aspect > 0 else {
                return CellSize(
                    cols: card.minimum.cols + step, rows: card.minimum.rows + step)
            }
            return CellSize(
                cols: card.minimum.cols + step,
                rows: card.minimum.rows + Int((Double(step) / aspect).rounded()))
        }

        /// The highest step on `grid` that the card still fits, or nil where its minimum does not.
        static func top(_ card: SchemaFacts.Card, grid: CellSize) -> Int? {
            func fits(_ size: CellSize) -> Bool { size.cols <= grid.cols && size.rows <= grid.rows }
            guard fits(size(card, step: 0)) else { return nil }
            var top = 0
            while fits(size(card, step: top + 1)) { top += 1 }
            return top
        }

        /// How a search for the smallest fitting size ended.
        enum Search<Plate> {
            /// The smallest step whose plate fits, and the plate that drew it.
            case found(step: Int, plate: Plate)
            /// No step fits, so the card is drawn at its minimum with its notice.
            case none
            /// A probe was refused or failed, so nothing more is asked.
            case failed
        }

        /// The smallest step in `0...top` whose plate fits, found by a binary search, which takes fit to
        /// hold at every larger size. `probe` draws the card at a step; `fits` reads its plate.
        static func smallestFitting<Plate>(
            top: Int, probe: (Int) async -> Plate?, fits: (Plate) -> Bool
        ) async -> Search<Plate> {
            guard let topPlate = await probe(top) else { return .failed }
            guard fits(topPlate) else { return .none }
            var (low, high, best) = (0, top, topPlate)
            while low < high {
                let middle = (low + high) / 2
                guard let plate = await probe(middle) else { return .failed }
                if fits(plate) {
                    (high, best) = (middle, plate)
                } else {
                    low = middle + 1
                }
            }
            return .found(step: high, plate: best)
        }
    }

    /// When a set's tiles are wanted: at once for the scene shown, in the library's lane, or
    /// ahead of any scene being opened, behind the thumbnails.
    enum Pace {
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
    var key: Key?
    var sets: [Key: TileSet] = [:]
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
        let cards = set.claim(source, pace)
        // The canvas gives a shown scene's backdrop, unless it holds no card to draw.
        let wantsBackdrop =
            set.backdrop == nil && !set.askedBackdrop
            && (pace == .ahead || content.layout.cards.isEmpty)
        let around =
            wantsBackdrop
            ? cards.lazy.compactMap({ card in
                Self.request(
                    for: draft, card: .tile(card.name, at: card.minimum), context: source.context)
            }).first ?? Self.any(draft, from: source) : nil
        if around != nil { set.askedBackdrop = true }
        sets[key] = set
        let backdrop = around.map {
            RenderRequest(
                doc: $0.doc, builtIn: $0.builtIn, context: source.context, plates: [],
                backdrop: true)
        }
        await send(cards, backdrop: backdrop, draft, pace, source)
    }

    /// Draws each card's tile and the backdrop's, where there is one, at `pace`, and keeps what
    /// they draw for the draft's settings. A request made ahead is named for its settings, so no
    /// other scene's replaces it.
    private func send(
        _ cards: [SchemaFacts.Card], backdrop: RenderRequest?, _ draft: Draft, _ pace: Pace,
        _ source: Source
    ) async {
        let key = Key(draft.laidOut, draft.content)
        let tag = pace == .shown ? "" : "ahead:\(key.hashValue):"
        await withTaskGroup(of: Void.self) { group in
            for card in cards {
                group.addTask {
                    await self.drawTile(card, draft, pace, source)
                }
            }
            if let backdrop {
                group.addTask {
                    let result = await source.queue.submit(
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
            request(for: draft, card: .tile(card.name, at: card.minimum), context: source.context)
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
        set.tiles = set.tiles.mapValues { Tile(layer: $0.layer, size: $0.size, over: backdrop) }
        set.setups = set.setups.mapValues { $0.over(backdrop) }
        sets[key] = set
    }

    /// Forgets every tile, as when another panel is shown.
    public func forget() {
        sets = [:]
        recent = []
        key = nil
    }

    /// A tile's request: `draft`'s scene as edited, holding only `card`, naming its one plate and
    /// no backdrop, or nil where the card is off the grid.
    static func request(for draft: Draft, card: LayoutCard, context: RenderContext)
        -> RenderRequest?
    {
        let laidOut = draft.laidOut
        let layout: SceneLayout
        do throws(LayoutRefusal) {
            layout = try SceneLayout(grid: laidOut.panel, cards: [card])
        } catch {
            return nil
        }
        return RenderRequest(
            doc: laidOut.doc(for: draft.content.with(layout: layout)),
            builtIn: laidOut.document.builtIn, context: context, plates: [0], backdrop: false)
    }

    /// Draws `card`'s tile in the draft's settings: at the size found for them, or where none is
    /// found yet, at the smallest size on the ladder whose plate shows the reading, found once and
    /// kept. Where no size fits, the tile is drawn at the card's declared minimum, with its notice.
    private func drawTile(
        _ card: SchemaFacts.Card, _ draft: Draft, _ pace: Pace, _ source: Source
    ) async {
        let key = Key(draft.laidOut, draft.content)
        let tag = pace == .shown ? "" : "ahead:\(key.hashValue):"
        let plate: (CellSize) async -> RenderedLayer? = { size in
            guard
                let request = Self.request(
                    for: draft, card: .tile(card.name, at: size), context: source.context)
            else { return nil }
            let result = await source.queue.submit(
                request.message, lane: pace.lane, key: "\(tag)tile:\(card.name)")
            return Self.plate(of: result)
        }
        guard let top = Ladder.top(card, grid: draft.laidOut.panel) else { return }
        let search = await Ladder.smallestFitting(
            top: top, probe: { step in await plate(Ladder.size(card, step: step)) },
            fits: { $0.unfit.isEmpty })
        switch search {
        case .found(let step, let found):
            settle(found, size: Ladder.size(card, step: step), card: card.name, drawnIn: key)
        case .none:
            settle(await plate(card.minimum), size: card.minimum, card: card.name, drawnIn: key)
        case .failed:
            settle(nil, size: card.minimum, card: card.name, drawnIn: key)
        }
    }

    /// Keeps `plate` as `card`'s tile at `size` in `key`'s settings, while they are held and the
    /// card is still asked for. Without a plate the card is no longer asked for, so it may be asked again.
    private func settle(_ plate: RenderedLayer?, size: CellSize, card: String, drawnIn key: Key) {
        guard var set = sets[key] else { return }
        defer { sets[key] = set }
        guard let plate else {
            set.asked.remove(card)
            set.ahead.remove(card)
            return
        }
        guard set.asked.contains(card) || set.ahead.contains(card) else { return }
        set.tiles[card] = Tile(layer: plate, size: size, over: set.backdrop)
    }

    /// The plate a tile's request drew, or nil where the answer refused or failed, or holds none.
    static func plate(of result: Result<HelperAnswer, RenderFailure>?) -> RenderedLayer? {
        guard case .success(let answer)? = result else { return nil }
        do throws(RenderFailure) {
            // The one placement's id is never read: a tile is known by its card's name.
            let layers = try RenderedLayer.layers(of: answer, cardIDs: [UUID()])
            return layers.first(where: { $0.kind == .plate })
        } catch {
            return nil
        }
    }
}

extension LayoutCard {
    /// The card `name` at `size` at the grid's top-left corner, holding `settings`: what a library
    /// tile draws.
    static func tile(_ name: String, at size: CellSize, settings: [String: JSONValue] = [:])
        -> LayoutCard
    {
        LayoutCard(
            kind: name, cells: CellRect(col: 0, row: 0, cols: size.cols, rows: size.rows),
            settings: settings)
    }
}

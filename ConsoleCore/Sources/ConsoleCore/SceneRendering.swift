import CoreGraphics
import Foundation
import Observation

/// One open scene's layers, kept matching the layout the canvas shows (`scene-rendering`). Each
/// plate's layer is kept with the cells it was drawn for, so the canvas can slide or stretch it to
/// where the plate is now until the plate is drawn again there.
@MainActor @Observable
public final class SceneRendering {
    public enum Status: Sendable, Equatable {
        /// The renderer has not made its first run yet.
        case waiting
        case drawing
        case drawn
        /// No renderer can draw: this build has none, or it could not start, and why.
        case noRenderer(String)
        /// The helper refused the scene, with the panel's reason.
        case refused(String)
        /// The helper ended while drawing.
        case failed
        /// Code every card draws through differs from the panel's: these shared entries.
        case codeDiffers([String])
    }

    /// A plate's layer, the cells its plate covered when it was drawn, and the settings its cards
    /// were drawn with, by card id.
    public struct PlacedLayer: Sendable {
        public let layer: RenderedLayer
        public let cells: CellRect
        public let settings: [UUID: [String: JSONValue]]

        /// What the plate was drawn from, to compare with what the layout wants now.
        var state: PlateState { PlateState(cells: cells, settings: settings) }
    }

    public private(set) var backdrop: RenderedLayer?
    public private(set) var plates: [Set<UUID>: PlacedLayer] = [:]
    /// The plates of cards parked off the panel (`card-parking`).
    public private(set) var parked = ParkedPlates()
    public private(set) var status = Status.waiting
    /// What the helper said about the backdrop's image, such as `BACKDROP IMAGE MISSING`.
    public private(set) var notice: String?
    /// How the app's card code differs from the panel's, where it does.
    public private(set) var drift: CardDrift?
    /// Whether the host gave the panel's display size, so the scene is not drawn at a stand-in.
    public let displayKnown: Bool
    public let context: RenderContext

    /// What one request draws.
    private enum Target: Sendable {
        /// The backdrop and every plate.
        case everything
        /// The backdrop alone, after a change to the scene's backdrop alone.
        case backdrop
        /// One plate, by its cards.
        case plate(Set<UUID>)

        /// The plates asked for, by their index among `ids`, the layout's cards in order: nil for
        /// every plate.
        func plates(among ids: [UUID]) -> [Int]? {
            switch self {
            case .everything: nil
            case .backdrop: []
            case .plate(let members): ids.firstIndex(where: members.contains).map { [$0] }
            }
        }

        var drawsBackdrop: Bool {
            switch self {
            case .everything, .backdrop: true
            case .plate: false
            }
        }

        /// The queue's key, so a newer request for the same thing replaces one not yet sent.
        var key: String {
            switch self {
            case .everything: "scene"
            case .backdrop: "backdrop"
            case .plate(let members):
                "plate:" + members.map(\.uuidString).sorted().joined(separator: ",")
            }
        }
    }

    /// The scene as read, its document and the content it opened with.
    public let scene: LaidOutScene
    private var queue: RenderQueue?
    private var content: SceneContent
    private var inFlight = 0

    public init(scene: LaidOutScene, context: RenderContext, displayKnown: Bool) {
        self.scene = scene
        self.context = context
        self.displayKnown = displayKnown
        content = scene.content
    }

    private var layout: SceneLayout { content.layout }

    /// Starts drawing with `queue`, once the renderer has made its first run.
    public func attach(_ queue: RenderQueue) async {
        if case .codeDiffers = status { return }
        self.queue = queue
        await show(content)
    }

    /// No renderer will draw this scene, for `reason`.
    public func unavailable(_ reason: String) {
        queue = nil
        clear(.noRenderer(reason))
    }

    /// Takes what comparing the card code found: a shared difference, or a damaged bundle, draws
    /// nothing by the helper; a card family's difference boxes that family's cards (`card-code`).
    public func apply(_ verdict: CardCodeVerdict) {
        switch verdict {
        case .same:
            drift = nil
        case .damagedBundle:
            unavailable("This app's render bundle doesn't match its manifest. Rebuild the app.")
        case .unreadable:
            unavailable("The panel's card code can't be read. Deploy audio-vue to the panel.")
        case .differs(let drift):
            self.drift = drift
            if drift.sharesNothing {
                queue = nil
                clear(.codeDiffers(drift.shared))
            }
        }
    }

    /// The cards drawn as plain boxes over their plates, their family's code differing.
    public var boxedCards: Set<UUID> {
        guard let drift else { return [] }
        return Set(content.cards.filter { drift.boxes($0.kind) }.map(\.id))
    }

    /// Draws again whatever `content` changed, dropping the layers of plates it no longer has: a
    /// change to the backdrop block alone draws the backdrop, a change to any other block draws
    /// everything, and a layout edit draws the plates it changed (`scene-settings`, design D6).
    /// A plate parked keeps its layer, and is drawn alone only when it must be (`card-parking`).
    public func show(_ content: SceneContent) async {
        let changedBlocks = Self.changedBlocks(from: self.content.blocks, to: content.blocks)
            .subtracting(RenderRequest.undrawnBlocks)
        self.content = content
        guard let queue else { return }
        let restyled = !changedBlocks.isSubset(of: [Self.backdropBlock])
        let alone = parked.sort(content, plates: &plates, restyled: restyled)
        let changes = PlateChanges.needed(drawn: plates.mapValues(\.state), for: content.layout)
        for removed in changes.removed { plates[removed] = nil }
        let targets =
            backdrop == nil || restyled
            ? [Target.everything]
            : changes.redraw.map(Target.plate) + (changedBlocks.isEmpty ? [] : [Target.backdrop])
        await withDiscardingTaskGroup { group in
            for target in targets {
                group.addTask { await self.draw(content, target, through: queue) }
            }
            for members in alone {
                group.addTask { await self.drawParked(members, content, through: queue) }
            }
        }
    }

    /// Draws the parked plate `members` of `content` alone, at the grid's top-left, as a library
    /// tile is drawn, keeping its layer where the plate is still parked (design D7).
    private func drawParked(
        _ members: Set<UUID>, _ content: SceneContent, through queue: RenderQueue
    )
        async
    {
        guard let alone = ParkedPlates.alone(members, of: content) else { return }
        let request = RenderRequest(
            doc: scene.doc(for: content.with(layout: alone)), builtIn: scene.document.builtIn,
            context: context, plates: [0], backdrop: false)
        let key = "parked:" + members.map(\.uuidString).sorted().joined(separator: ",")
        begin()
        let result = await queue.submit(request.message, lane: .canvas, key: key)
        defer { end() }
        guard self.queue != nil, case .success(let answer)? = result else { return }
        do {
            let layers = try RenderedLayer.layers(of: answer, cardIDs: alone.cards.map(\.id))
            for layer in layers { parked.take(layer, drawnFor: alone, in: self.content) }
        } catch {
            return
        }
    }

    private static let backdropBlock = "backdrop"

    /// The blocks that differ between `old` and `new`, by name.
    private static func changedBlocks(
        from old: [String: JSONValue], to new: [String: JSONValue]
    ) -> Set<String> {
        Set(old.keys).union(new.keys).filter { old[$0] != new[$0] }
    }

    /// The names of the cards, on the grid or parked, that cannot show their reading at the size
    /// drawn.
    public var unfit: [String] {
        (plates.values.flatMap(\.layer.unfit) + parked.layers.values.flatMap(\.layer.unfit))
            .sorted()
    }

    /// The plates' layers in the order the helper stacks them: cards in no group in placement
    /// order, then the groups.
    public var orderedPlates: [PlacedLayer] {
        let order = Dictionary(
            uniqueKeysWithValues: layout.cards.enumerated().map { ($1.id, $0) })
        return plates.values.sorted { first, second in
            let firstGrouped = first.layer.cardIDs.count > 1
            let secondGrouped = second.layer.cardIDs.count > 1
            if firstGrouped != secondGrouped { return secondGrouped }
            return Self.position(of: first, in: order) < Self.position(of: second, in: order)
        }
    }

    /// Draws `target` as `content` holds the scene.
    private func draw(_ content: SceneContent, _ target: Target, through queue: RenderQueue) async {
        let layout = content.layout
        // A scene with no cards is the app's alone until one is placed (`scene-gallery`, "New
        // Scene"): the host holds and draws none, so nothing is asked and the grid shows bare.
        // One too wide for the panel the helper would refuse, so it stays as boxes
        // (`scene-rendering`, "A scene too wide is drawn as boxes").
        guard !layout.cards.isEmpty, !scene.isTooWide(content) else {
            clear(.drawn, keepingParked: true)
            return
        }
        let ids = layout.cards.map(\.id)
        let request = RenderRequest(
            doc: scene.doc(for: content), builtIn: scene.document.builtIn, context: context,
            plates: target.plates(among: ids), backdrop: target.drawsBackdrop)
        begin()
        let result = await queue.submit(request.message, lane: .canvas, key: target.key)
        defer { end() }
        // A verdict or a failure that stopped drawing while this was under way wins over its answer.
        guard self.queue != nil else { return }
        switch result {
        case nil: return
        case .success(let answer)?: take(answer, drawnFor: layout, cardIDs: ids)
        case .failure(.refused(let reason))?: clear(.refused(reason))
        case .failure(.unavailable(let reason))?: clear(.noRenderer(reason))
        case .failure?: clear(.failed)
        }
    }

    private func take(_ answer: HelperAnswer, drawnFor drawn: SceneLayout, cardIDs: [UUID]) {
        let layers: [RenderedLayer]
        do {
            layers = try RenderedLayer.layers(of: answer, cardIDs: cardIDs)
        } catch {
            clear(.failed)
            return
        }
        notice = answer.header["notice"]?.stringValue
        let current = PlateChanges.cells(of: layout)
        let drawnStates = PlateChanges.drawn(of: drawn)
        for layer in layers {
            let members = Set(layer.cardIDs)
            if layer.kind == .backdrop {
                backdrop = layer
            } else if current[members] != nil, let state = drawnStates[members] {
                plates[members] = PlacedLayer(
                    layer: layer, cells: state.cells, settings: state.settings)
            }
        }
    }

    /// Drops every layer, the parked plates' too unless `keepingParked`, which are drawn alone
    /// whatever the scene's own drawing.
    private func clear(_ status: Status, keepingParked: Bool = false) {
        backdrop = nil
        plates = [:]
        if !keepingParked { parked.clear() }
        notice = nil
        self.status = status
    }

    private func begin() {
        inFlight += 1
        switch status {
        case .noRenderer, .codeDiffers: return
        default: status = .drawing
        }
    }

    private func end() {
        inFlight -= 1
        if inFlight == 0, status == .drawing { status = .drawn }
    }

    private static func position(of placed: PlacedLayer, in order: [UUID: Int]) -> Int {
        placed.layer.cardIDs.compactMap { order[$0] }.min() ?? Int.max
    }
}
